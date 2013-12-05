# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/should'

module Transpec
  class Syntax
    describe Should do
      include_context 'parsed objects'
      include_context 'syntax object', Should, :should_object

      let(:record) { should_object.report.records.first }

      describe '#matcher_node' do
        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
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
              describe 'example' do
                it 'is empty' do
                  subject.should be_empty
                end
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
              describe 'example' do
                it 'is 1' do
                  subject.should eq(1)
                end
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

      describe '#operator_matcher' do
        subject { should_object.operator_matcher }

        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          it 'returns an instance of OperatorMatcher' do
            should be_an(OperatorMatcher)
          end
        end

        context 'when it is taking non-operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  subject.should be_empty
                end
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end
      end

      describe '#have_matcher' do
        subject { should_object.have_matcher }

        context 'when it is taking #have matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  subject.should have(2).items
                end
              end
            END
          end

          it 'returns an instance of Have' do
            should be_an(Have)
          end
        end

        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end

        context 'when it is taking any other non-operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  subject.should be_empty
                end
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end
      end

      describe '#expectize!' do
        context 'when it has an operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          it 'invokes OperatorMatcher#convert_operator!' do
            should_object.operator_matcher.should_receive(:convert_operator!)
            should_object.expectize!
          end
        end

        context 'when it is `subject.should` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should eq(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  expect(subject).to eq(1)
                end
              end
            END
          end

          it 'converts into `expect(subject).to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.should` -> `expect(obj).to`' do
            should_object.expectize!
            record.original_syntax.should  == 'obj.should'
            record.converted_syntax.should == 'expect(obj).to'
          end

          context 'and #expect is available in the context by including RSpec::Matchers' do
            let(:source) do
              <<-END
                describe 'example' do
                  class TestRunner
                    include RSpec::Matchers

                    def run
                      1.should == 1
                    end
                  end

                  it 'is 1' do
                    TestRunner.new.run
                  end
                end
              END
            end

            context 'with runtime information' do
              include_context 'dynamic analysis objects'

              it 'does not raise InvalidContextError' do
                -> { should_object.expectize! }.should_not raise_error
              end
            end

            context 'without runtime information' do
              it 'raises InvalidContextError' do
                -> { should_object.expectize! }.should raise_error(InvalidContextError)
              end
            end
          end

          context 'and #expect is not available in the context' do
            context 'and the context is determinable statically' do
              let(:source) do
                <<-END
                  describe 'example' do
                    class TestRunner
                      def run
                        1.should == 1
                      end
                    end

                    it 'is 1' do
                      TestRunner.new.run
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises InvalidContextError' do
                  -> { should_object.expectize! }.should raise_error(InvalidContextError)
                end
              end

              context 'without runtime information' do
                it 'raises InvalidContextError' do
                  -> { should_object.expectize! }.should raise_error(InvalidContextError)
                end
              end
            end

            context 'and the context is not determinable statically' do
              let(:source) do
                <<-END
                  def my_eval(&block)
                    Object.new.instance_eval(&block)
                  end

                  describe 'example' do
                    it 'responds to #foo' do
                      my_eval { 1.should == 1 }
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises InvalidContextError' do
                  -> { should_object.expectize! }.should raise_error(InvalidContextError)
                end
              end

              context 'without runtime information' do
                it 'does not raise InvalidContextError' do
                  -> { should_object.expectize! }.should_not raise_error
                end
              end
            end
          end
        end

        context 'when it is `subject.should_not` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is not 1' do
                  subject.should_not eq(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is not 1' do
                  expect(subject).not_to eq(1)
                end
              end
            END
          end

          it 'converts into `expect(subject).not_to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.should_not` -> `expect(obj).not_to`' do
            should_object.expectize!
            record.original_syntax.should  == 'obj.should_not'
            record.converted_syntax.should == 'expect(obj).not_to'
          end

          context 'and "to_not" is passed as negative form' do
            let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is not 1' do
                  expect(subject).to_not eq(1)
                end
              end
            END
            end

            it 'converts into `expect(subject).to_not` form' do
              should_object.expectize!('to_not')
              rewritten_source.should == expected_source
            end

            it 'adds record `obj.should_not` -> `expect(obj).to_not`' do
              should_object.expectize!('to_not')
              record.original_syntax.should  == 'obj.should_not'
              record.converted_syntax.should == 'expect(obj).to_not'
            end
          end
        end

        context 'when it is `(subject).should` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is true' do
                  (1 == 1).should be_true
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is true' do
                  expect(1 == 1).to be_true
                end
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
              describe 'example' do
                it 'is 1' do
                  subject.should() == 1
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  expect(subject).to eq(1)
                end
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
                describe 'example' do
                  it 'raises error' do
                    #{method} { fail }.should raise_error
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'raises error' do
                    expect { fail }.to raise_error
                  end
                end
              END
            end

            it 'converts into `expect {...}.to` form' do
              should_object.expectize!
              rewritten_source.should == expected_source
            end

            it "adds record `#{method} { }.should` -> `expect { }.to`" do
              should_object.expectize!
              record.original_syntax.should  == "#{method} { }.should"
              record.converted_syntax.should == 'expect { }.to'
            end
          end
        end

        ['MyObject.lambda', 'MyObject.proc', 'MyObject.new'].each do |method|
          context "when it is `#{method} { ... }.should` form" do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'is 1' do
                    #{method} { fail }.should eq(1)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'is 1' do
                    expect(#{method} { fail }).to eq(1)
                  end
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
              describe 'example' do
                it 'increments all elements' do
                  [1, 2].map { |i| i + 1 }.should eq([2, 3])
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'increments all elements' do
                  expect([1, 2].map { |i| i + 1 }).to eq([2, 3])
                end
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
