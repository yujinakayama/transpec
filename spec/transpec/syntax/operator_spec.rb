# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/operator'
require 'transpec/syntax/should'

module Transpec
  class Syntax
    describe Operator do
      include ::AST::Sexp
      include_context 'parsed objects'
      include_context 'syntax object', Should, :should_object

      subject(:matcher) { should_object.operator_matcher }
      let(:record) { matcher.report.records.first }

      describe '#method_name' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'is 1' do
                subject.should == 1
              end
            end
          END
        end

        it 'returns the method name' do
          matcher.method_name.should == :==
        end
      end

      describe '#convert_operator!' do
        before do
          matcher.convert_operator!(parenthesize_arg)
        end

        let(:parenthesize_arg) { true }

        context 'with expression `== 1`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq(1)
                end
              end
            END
          end

          it 'converts to `eq(1)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `== expected` -> `eq(expected)`' do
            record.old_syntax.should == '== expected'
            record.new_syntax.should == 'eq(expected)'
            record.annotation.should be_nil
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
                describe 'example' do
                  it 'is 1' do
                    subject.should ==
                      1
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'is 1' do
                    subject.should eq(
                      1
                    )
                  end
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

        context 'with expression `==1`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should==1
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq(1)
                end
              end
            END
          end

          it 'converts to `eq(1)` form' do
            rewritten_source.should == expected_source
          end

          context 'and false is passed as `parenthesize_arg` argument' do
            let(:parenthesize_arg) { false }

            let(:expected_source) do
              <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq 1
                end
              end
              END
            end

            it 'converts to `eq 1` form' do
              rewritten_source.should == expected_source
            end
          end
        end

        context 'with expression `be == 1`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should be == 1
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq(1)
                end
              end
            END
          end

          it 'converts to `eq(1)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `== expected` -> `eq(expected)`' do
            record.old_syntax.should == '== expected'
            record.new_syntax.should == 'eq(expected)'
            record.annotation.should be_nil
          end
        end

        context 'with expression `be.==(1)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should be.==(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq(1)
                end
              end
            END
          end

          it 'converts to `eq(1)` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `== (2 - 1)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == (2 - 1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq(2 - 1)
                end
              end
            END
          end

          it 'converts to `eq(2 - 1)` form without superfluous parentheses' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `== (5 - 3) / (4 - 2)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == (5 - 3) / (4 - 2)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq((5 - 3) / (4 - 2))
                end
              end
            END
          end

          it 'converts to `eq((5 - 3) / (4 - 2))` form' do
            rewritten_source.should == expected_source
          end
        end

        context "with expression `== { 'key' => 'value' }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is the hash' do
                  subject.should == { 'key' => 'value' }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is the hash' do
                  subject.should eq({ 'key' => 'value' })
                end
              end
            END
          end

          it "converts to `eq({ 'key' => 'value' })` form" do
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
          context "with expression `#{operator} 1`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it '#{description} 1' do
                    subject.should #{operator} 1
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it '#{description} 1' do
                    subject.should be #{operator} 1
                  end
                end
              END
            end

            it "converts to `be #{operator} 1` form" do
              rewritten_source.should == expected_source
            end

            it "adds record `#{operator} expected` -> `be #{operator} expected`" do
              record.old_syntax.should == "#{operator} expected"
              record.new_syntax.should == "be #{operator} expected"
              record.annotation.should be_nil
            end
          end

          context "with expression `be #{operator} 1`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it '#{description} 1' do
                    subject.should be #{operator} 1
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end

            it 'reports nothing' do
              matcher.report.records.should be_empty
            end
          end
        end

        context 'with expression `=~ /pattern/`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'matches the pattern' do
                  subject.should =~ /pattern/
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'matches the pattern' do
                  subject.should match(/pattern/)
                end
              end
            END
          end

          it 'converts to `match(/pattern/)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `=~ /pattern/` -> `match(/pattern/)` without annotation' do
            record.old_syntax.should == '=~ /pattern/'
            record.new_syntax.should == 'match(/pattern/)'
            record.annotation.should be_nil
          end
        end

        context 'with expression `=~/pattern/`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'matches the pattern' do
                  subject.should=~/pattern/
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'matches the pattern' do
                  subject.should match(/pattern/)
                end
              end
            END
          end

          it 'converts to `match(/pattern/)` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `be =~ /pattern/`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'matches the pattern' do
                  subject.should be =~ /pattern/
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'matches the pattern' do
                  subject.should match(/pattern/)
                end
              end
            END
          end

          it 'converts to `match(/pattern/)` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `=~ [1, 2]`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'contains 1 and 2' do
                  subject.should =~ [1, 2]
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'contains 1 and 2' do
                  subject.should match_array([1, 2])
                end
              end
            END
          end

          it 'converts to `match_array([1, 2])` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `=~ [1, 2]` -> `match_array([1, 2])` without annotation' do
            record.old_syntax.should == '=~ [1, 2]'
            record.new_syntax.should == 'match_array([1, 2])'
            record.annotation.should be_nil
          end
        end

        context 'with expression `=~[1, 2]`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'contains 1 and 2' do
                  subject.should=~[1, 2]
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'contains 1 and 2' do
                  subject.should match_array([1, 2])
                end
              end
            END
          end

          it 'converts to `match_array([1, 2])` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `be =~ [1, 2]`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'contains 1 and 2' do
                  subject.should be =~ [1, 2]
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'contains 1 and 2' do
                  subject.should match_array([1, 2])
                end
              end
            END
          end

          it 'converts to `match_array([1, 2])` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `=~ variable`' do
          context 'and runtime type of the variable is array' do
            include_context 'dynamic analysis objects'

            let(:source) do
              <<-END
                describe 'example' do
                  it 'contains 1 and 2' do
                    variable = [1, 2]
                    [2, 1].should =~ variable
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'contains 1 and 2' do
                    variable = [1, 2]
                    [2, 1].should match_array(variable)
                  end
                end
              END
            end

            it 'converts to `match_array(variable)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `=~ [1, 2]` -> `match_array([1, 2])` without annotation' do
              record.old_syntax.should == '=~ [1, 2]'
              record.new_syntax.should == 'match_array([1, 2])'
              record.annotation.should be_nil
            end
          end

          context 'and runtime type of the variable is regular expression' do
            include_context 'dynamic analysis objects'

            let(:source) do
              <<-END
                describe 'example' do
                  it 'matches to the pattern' do
                    variable = /^str/
                    'string'.should =~ variable
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'matches to the pattern' do
                    variable = /^str/
                    'string'.should match(variable)
                  end
                end
              END
            end

            it 'converts to `match(variable)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `=~ /pattern/` -> `match(/pattern/)` without annotation' do
              record.old_syntax.should == '=~ /pattern/'
              record.new_syntax.should == 'match(/pattern/)'
              record.annotation.should be_nil
            end
          end

          context 'and no runtime type information is provided' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'matches the pattern' do
                    subject.should =~ variable
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'matches the pattern' do
                    subject.should match(variable)
                  end
                end
              END
            end

            it 'converts to `match(variable)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `=~ /pattern/` -> `match(/pattern/)` with annotation' do
              record.old_syntax.should == '=~ /pattern/'
              record.new_syntax.should == 'match(/pattern/)'

              record.annotation.message.should ==
                'The `=~ variable` has been converted but it might possibly be incorrect ' \
                "due to a lack of runtime information. It's recommended to review the change carefully."
              record.annotation.source_range.source.should == '=~ variable'
            end
          end
        end

        context 'with expression `be =~ variable`' do
          context 'and no runtime type information is provided' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'matches the pattern' do
                    subject.should be =~ variable
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'matches the pattern' do
                    subject.should match(variable)
                  end
                end
              END
            end

            it 'converts to `match(variable)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `=~ /pattern/` -> `match(/pattern/)` with annotation' do
              record.old_syntax.should == '=~ /pattern/'
              record.new_syntax.should == 'match(/pattern/)'

              record.annotation.message.should ==
                'The `be =~ variable` has been converted but it might possibly be incorrect ' \
                "due to a lack of runtime information. It's recommended to review the change carefully."
              record.annotation.source_range.source.should == 'be =~ variable'
            end
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
              describe 'example' do
                it 'is 1' do
                  subject.should ==(1)
                end
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
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          context 'and true is passed as `always` argument' do
            let(:always) { true }

            let(:expected_source) do
              <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should ==(1)
                end
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
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
              END
            end

            it 'does not nothing' do
              rewritten_source.should == expected_source
            end
          end
        end

        context 'when its argument is a string literal' do
          let(:source) do
            <<-END
              describe 'example' do
                it "is 'string'" do
                  subject.should == 'string'
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it "is 'string'" do
                  subject.should ==('string')
                end
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
              describe 'example' do
                it 'returns the document' do
                  subject.should == <<-HEREDOC
                  foo
                  HEREDOC
                end
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

        context 'when its argument is a here document with chained method' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'returns the document' do
                  subject.should == <<-HEREDOC.gsub('foo', 'bar')
                  foo
                  HEREDOC
                end
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
          #       (send
          #         (str "                foo\n") :gsub
          #         (str "foo")
          #         (str "bar")))))

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'when its argument is a here document with interpolation' do
          let(:source) do
            <<-'END'
              it 'returns the document' do
                string = 'foo'
                subject.should == <<-HEREDOC
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
    end
  end
end
