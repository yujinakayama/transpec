# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/matcher'

module Transpec
  class Syntax
    describe Matcher do
      include_context 'parsed objects'
      include_context 'should object'

      subject(:matcher) do
        Matcher.new(should_object.matcher_node, in_example_group_context?, source_rewriter)
      end

      let(:in_example_group_context?) { true }

      describe '#method_name' do
        context 'when it is operator matcher' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should == 1
              end
            END
          end

          # (block
          #   (send nil :it
          #     (str "is 1"))
          #   (args)
          #   (send
          #     (send
          #       (send nil :subject) :should) :==
          #     (int 1)))

          it 'returns the method name' do
            matcher.method_name.should == :==
          end
        end

        context 'when it is non-operator matcher' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should eq(1)
              end
            END
          end

          # (block
          #   (send nil :it
          #     (str "is 1"))
          #   (args)
          #   (send
          #     (send nil :subject) :should
          #     (send nil :eq
          #       (int 1))))

          it 'returns the method name' do
            matcher.method_name.should == :eq
          end
        end
      end

      describe '#correct_operator!' do
        before do
          matcher.correct_operator!(parenthesize_arg)
        end

        let(:parenthesize_arg) { true }

        context 'when it is `== 1` form' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should == 1
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is 1' do
                subject.should eq(1)
              end
            END
          end

          it 'converts into `eq(1)` form' do
            rewritten_source.should == expected_source
          end

          # Operator methods allow their argument to be in the next line,
          # but non-operator methods do not.
          #
          # [1] pry(main)> 1 ==
          # [1] pry(main)* 1
          # => true
          # [2] pry(main)> 1.eql?
          # ArgumentError: wrong number of arguments (0 for 1)
          context 'and its argument is in the next line' do
            let(:source) do
              <<-END
                it 'is 1' do
                  subject.should ==
                    1
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'is 1' do
                  subject.should eq(
                    1
                  )
                end
              END
            end

            it 'inserts parentheses properly' do
              rewritten_source.should == expected_source
            end

            context 'and false is passed as `parenthesize_arg` argument' do
              let(:parenthesize_arg) { false }

              it 'inserts parentheses properly because they are necessary' do
                rewritten_source.should == expected_source
              end
            end
          end
        end

        context "when it is `== { 'key' => 'value' }` form" do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should == { 'key' => 'value' }
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is 1' do
                subject.should eq({ 'key' => 'value' })
              end
            END
          end

          it "converts into `eq({ 'key' => 'value' })` form" do
            rewritten_source.should == expected_source
          end

          context 'and false is passed as `parenthesize_arg` argument' do
            let(:parenthesize_arg) { false }

            it 'inserts parentheses to avoid the hash from be interpreted as a block' do
              rewritten_source.should == expected_source
            end
          end
        end

        [
          [:===, 'case-equals to'],
          [:<,   'is less than'],
          [:<=,  'is less than or equals to'],
          [:>,   'is greater than'],
          [:>=,  'is greater than or equals to']
        ].each do |operator, description|
          context "when it is `#{operator} 1` form" do
            let(:source) do
              <<-END
                it '#{description} 1' do
                  subject.should #{operator} 1
                end
              END
            end

            let(:expected_source) do
              <<-END
                it '#{description} 1' do
                  subject.should be #{operator} 1
                end
              END
            end

            it "converts into `be #{operator} 1` form" do
              rewritten_source.should == expected_source
            end
          end
        end

        context 'when it is `=~ /pattern/` form' do
          let(:source) do
            <<-END
              it 'matches the pattern' do
                subject.should =~ /pattern/
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'matches the pattern' do
                subject.should match(/pattern/)
              end
            END
          end

          it 'converts into `match(/pattern/)` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `=~ [1, 2]` form' do
          let(:source) do
            <<-END
              it 'contains 1 and 2' do
                subject.should =~ [1, 2]
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'contains 1 and 2' do
                subject.should match_array([1, 2])
              end
            END
          end

          it 'converts into `match_array([1, 2])` form' do
            rewritten_source.should == expected_source
          end
        end
      end

      describe '#parenthesize!' do
        before do
          matcher.parenthesize!(always)
        end

        let(:always) { true }

        context 'when its argument is already in parentheses' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should eq(1)
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'when its argument is not in parentheses' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should eq 1
              end
            END
          end

          context 'and true is passed as `always` argument' do
            let(:always) { true }

            let(:expected_source) do
            <<-END
              it 'is 1' do
                subject.should eq(1)
              end
            END
            end

            it 'inserts parentheses' do
              rewritten_source.should == expected_source
            end
          end

          context 'and false is passed as `always` argument' do
            let(:always) { false }

            let(:expected_source) do
            <<-END
              it 'is 1' do
                subject.should eq 1
              end
            END
            end

            it 'does not nothing' do
              rewritten_source.should == expected_source
            end
          end
        end

        context 'when its multiple arguments are not in parentheses' do
          let(:source) do
            <<-END
              it 'contains 1 and 2' do
                subject.should include 1, 2
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'contains 1 and 2' do
                subject.should include(1, 2)
              end
            END
          end

          it 'inserts parentheses' do
            rewritten_source.should == expected_source
          end
        end

        context 'when its argument is a string literal' do
          let(:source) do
            <<-END
              it "is 'string'" do
                subject.should eq 'string'
              end
            END
          end

          let(:expected_source) do
            <<-END
              it "is 'string'" do
                subject.should eq('string')
              end
            END
          end

          it 'inserts parentheses' do
            rewritten_source.should == expected_source
          end
        end

        context 'when its argument is a here document' do
          let(:source) do
            <<-END
              it 'returns the document' do
                subject.should eq <<-HEREDOC
                foo
                HEREDOC
              end
            END
          end

          # (block
          #   (send nil :it
          #     (str "returns the document"))
          #   (args)
          #   (send
          #     (send nil :subject) :should
          #     (send nil :eq
          #       (str "                foo\n"))))

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'when its argument is a here document with interpolation' do
          let(:source) do
            <<-'END'
              it 'returns the document' do
                string = 'foo'
                subject.should eq <<-HEREDOC
                #{string}
                HEREDOC
              end
            END
          end

          # (block
          #   (send nil :it
          #     (str "returns the document"))
          #   (args)
          #   (begin
          #     (lvasgn :string
          #       (str "foo"))
          #     (send
          #       (send nil :subject) :should
          #       (send nil :eq
          #         (dstr
          #           (str "                ")
          #           (begin
          #             (lvar :string))
          #           (str "\n"))))))

          it 'does nothing' do
            rewritten_source.should == source
          end
        end
      end

      describe '#convert_deprecated_method!' do
        before do
          matcher.convert_deprecated_method!
        end

        context 'when it is `be_close(expected, delta)` form' do
          let(:source) do
            <<-END
              it 'is close to 0.333' do
                (1.0 / 3.0).should be_close(0.333, 0.001)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is close to 0.333' do
                (1.0 / 3.0).should be_within(0.001).of(0.333)
              end
            END
          end

          it 'converts into `be_within(delta).of(expected)` form' do
            rewritten_source.should == expected_source
          end
        end
      end
    end
  end
end
