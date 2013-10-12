# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/should'

module Transpec
  class Syntax
    describe Should do
      include_context 'parsed objects'
      include_context 'should object'

      let(:record) { should_object.report.records.first }

      before do
        should_object.context.stub(:expect_to_matcher_available?).and_return(true)
      end

      describe '#matcher_node' do
        context 'when it is taking operator matcher' do
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

          it 'returns its parent node' do
            should_object.parent_node.children[1].should == :==
            should_object.matcher_node.should == should_object.parent_node
          end
        end

        context 'when it is taking non-operator matcher without argument' do
          let(:source) do
            <<-END
              it 'is empty' do
                subject.should be_empty
              end
            END
          end

          # (block
          #   (send nil :it
          #     (str "is empty"))
          #   (args)
          #   (send
          #     (send nil :subject) :should
          #     (send nil :be_empty)))

          it 'returns its argument node' do
            should_object.arg_node.children[1].should == :be_empty
            should_object.matcher_node.should == should_object.arg_node
          end
        end

        context 'when it is taking non-operator matcher with argument' do
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

          it 'returns its argument node' do
            should_object.arg_node.children[1].should == :eq
            should_object.matcher_node.should == should_object.arg_node
          end
        end
      end

      describe '#expectize!' do
        let(:source) do
          <<-END
            it 'is 1' do
              subject.should == 1
            end
          END
        end

        it 'invokes Matcher#correct_operator!' do
          should_object.matcher.should_receive(:correct_operator!)
          should_object.expectize!
        end

        context 'when it is `subject.should` form' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should eq(1)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is 1' do
                expect(subject).to eq(1)
              end
            END
          end

          it 'converts into `expect(subject).to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record "`obj.should` -> `expect(obj).to`"' do
            should_object.expectize!
            record.original_syntax.should  == 'obj.should'
            record.converted_syntax.should == 'expect(obj).to'
          end
        end

        context 'when it is `subject.should_not` form' do
          let(:source) do
            <<-END
              it 'is not 1' do
                subject.should_not eq(1)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is not 1' do
                expect(subject).not_to eq(1)
              end
            END
          end

          it 'converts into `expect(subject).not_to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record "`obj.should_not` -> `expect(obj).not_to`"' do
            should_object.expectize!
            record.original_syntax.should  == 'obj.should_not'
            record.converted_syntax.should == 'expect(obj).not_to'
          end

          context 'and "to_not" is passed as negative form' do
            let(:expected_source) do
            <<-END
              it 'is not 1' do
                expect(subject).to_not eq(1)
              end
            END
            end

            it 'converts into `expect(subject).to_not` form' do
              should_object.expectize!('to_not')
              rewritten_source.should == expected_source
            end

            it 'adds record "`obj.should_not` -> `expect(obj).to_not`"' do
              should_object.expectize!('to_not')
              record.original_syntax.should  == 'obj.should_not'
              record.converted_syntax.should == 'expect(obj).to_not'
            end
          end
        end

        context 'when it is `(subject).should` form' do
          let(:source) do
            <<-END
              it 'is true' do
                (1 == 1).should be_true
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is true' do
                expect(1 == 1).to be_true
              end
            END
          end

          it 'converts into `expect(subject).to` form without superfluous parentheses' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `subject.should() == 1` form' do
          let(:source) do
            <<-END
              it 'is 1' do
                subject.should() == 1
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'is 1' do
                expect(subject).to eq(1)
              end
            END
          end

          it 'converts into `expect(subject).to eq(1)` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        [
          'lambda', 'Kernel.lambda', '::Kernel.lambda',
          'proc', 'Kernel.proc', '::Kernel.proc',
          'Proc.new', '::Proc.new',
          '->'
        ].each do |method|
          context "when it is `#{method} { ... }.should` form" do
            let(:source) do
              <<-END
                it 'raises error' do
                  #{method} { fail }.should raise_error
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'raises error' do
                  expect { fail }.to raise_error
                end
              END
            end

            it 'converts into `expect {...}.to` form' do
              should_object.expectize!
              rewritten_source.should == expected_source
            end

            it 'adds record "`lambda { }.should` -> `expect { }.to`"' do
              should_object.expectize!
              record.original_syntax.should  == 'lambda { }.should'
              record.converted_syntax.should == 'expect { }.to'
            end
          end
        end

        ['MyObject.lambda', 'MyObject.proc', 'MyObject.new'].each do |method|
          context "when it is `#{method} { ... }.should` form" do
            let(:source) do
              <<-END
                it 'is 1' do
                  #{method} { fail }.should eq(1)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'is 1' do
                  expect(#{method} { fail }).to eq(1)
                end
              END
            end

            it "converts into `expect(#{method} { ... }).to` form" do
              should_object.expectize!
              rewritten_source.should == expected_source
            end
          end
        end

        context 'when it is `method { ... }.should` form but the subject value is not proc' do
          let(:source) do
            <<-END
              it 'increments all elements' do
                [1, 2].map { |i| i + 1 }.should eq([2, 3])
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'increments all elements' do
                expect([1, 2].map { |i| i + 1 }).to eq([2, 3])
              end
            END
          end

          it 'converts into `expect(method { ... }).to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end
      end
    end
  end
end
