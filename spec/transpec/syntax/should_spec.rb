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
        let(:matcher_name) { should_object.matcher_node.children[1] }

        context 'when the matcher is operator' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          it 'returns the matcher node' do
            matcher_name.should == :==
          end
        end

        context 'when the matcher is not operator' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is empty' do
                  subject.should be_empty
                end
              end
            END
          end

          it 'returns the matcher node' do
            matcher_name.should == :be_empty
          end
        end

        context 'when the matcher is chained by another method' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  subject.should have(2).items
                end
              end
            END
          end

          it 'returns the matcher node' do
            matcher_name.should == :have
          end
        end

        context 'when the matcher is chained by another method that is taking a block' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  subject.should have(2).items { }
                end
              end
            END
          end

          it 'returns the first node of the chain' do
            matcher_name.should == :have
          end
        end
      end

      describe '#operator_matcher' do
        subject { should_object.operator_matcher }

        let(:source) do
          <<-END
            describe 'example' do
              it 'is 1' do
                subject.should == 1
              end
            end
          END
        end

        it 'returns an instance of Operator' do
          should be_an(Operator)
        end
      end

      describe '#have_matcher' do
        subject { should_object.have_matcher }

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

      describe '#raise_error_matcher' do
        subject { should_object.raise_error_matcher }

        let(:source) do
          <<-END
            describe 'example' do
              it 'raises error' do
                lambda { do_something }.should raise_error
              end
            end
          END
        end

        it 'returns an instance of RaiseError' do
          should be_an(RaiseError)
        end
      end

      describe '#dependent_syntaxes' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'has 2 items' do
                subject.should have(2).items
              end
            end
          END
        end

        it 'returns an array containing #have_matcher, #operator_matcher, #raise_error_matcher' do
          should_object.dependent_syntaxes.should =~ [
            should_object.have_matcher,
            should_object.operator_matcher,
            should_object.raise_error_matcher
          ]
        end
      end

      describe '#expectize!' do
        context 'with expression `obj.should`' do
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

          it 'converts to `expect(obj).to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.should` -> `expect(obj).to`' do
            should_object.expectize!
            record.old_syntax.should == 'obj.should'
            record.new_syntax.should == 'expect(obj).to'
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

              it 'does not raise ContextError' do
                -> { should_object.expectize! }.should_not raise_error
              end
            end

            context 'without runtime information' do
              it 'raises ContextError' do
                -> { should_object.expectize! }.should raise_error(ContextError)
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

                it 'raises ContextError' do
                  -> { should_object.expectize! }.should raise_error(ContextError)
                end
              end

              context 'without runtime information' do
                it 'raises ContextError' do
                  -> { should_object.expectize! }.should raise_error(ContextError)
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

                it 'raises ContextError' do
                  -> { should_object.expectize! }.should raise_error(ContextError)
                end
              end

              context 'without runtime information' do
                it 'does not raise ContextError' do
                  -> { should_object.expectize! }.should_not raise_error
                end
              end
            end
          end
        end

        context 'with expression `obj.should_not`' do
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

          it 'converts to `expect(obj).not_to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.should_not` -> `expect(obj).not_to`' do
            should_object.expectize!
            record.old_syntax.should == 'obj.should_not'
            record.new_syntax.should == 'expect(obj).not_to'
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

            it 'converts to `expect(obj).to_not` form' do
              should_object.expectize!('to_not')
              rewritten_source.should == expected_source
            end

            it 'adds record `obj.should_not` -> `expect(obj).to_not`' do
              should_object.expectize!('to_not')
              record.old_syntax.should == 'obj.should_not'
              record.new_syntax.should == 'expect(obj).to_not'
            end
          end
        end

        context 'with expression `(obj).should`' do
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

          it 'converts to `expect(obj).to` form without superfluous parentheses' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `obj.should() == 1`' do
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
                  expect(subject).to == 1
                end
              end
            END
          end

          it 'converts to `expect(obj).to == 1` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        [
          'lambda', 'Kernel.lambda', '::Kernel.lambda',
          'proc', 'Kernel.proc', '::Kernel.proc',
          'Proc.new', '::Proc.new',
          '->',
          'expect'
        ].each do |method|
          context "with expression `#{method} { ... }.should`" do
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

            it 'converts to `expect {...}.to` form' do
              should_object.expectize!
              rewritten_source.should == expected_source
            end

            it "adds record `#{method} { }.should` -> `expect { }.to`" do
              should_object.expectize!
              record.old_syntax.should == "#{method} { }.should"
              record.new_syntax.should == 'expect { }.to'
            end
          end
        end

        ['MyObject.lambda', 'MyObject.proc', 'MyObject.new'].each do |method|
          context "with expression `#{method} { ... }.should`" do
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

            it "converts to `expect(#{method} { ... }).to` form" do
              should_object.expectize!
              rewritten_source.should == expected_source
            end
          end
        end

        context 'with expression `method { ... }.should` but the subject object is not proc' do
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

          it 'converts to `expect(method { ... }).to` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end
      end
    end
  end
end
