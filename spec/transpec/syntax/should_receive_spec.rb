# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/should_receive'

module Transpec
  class Syntax
    describe ShouldReceive do
      include_context 'parsed objects'

      subject(:should_receive_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless ShouldReceive.target_node?(node)
          return ShouldReceive.new(
            node,
            ancestor_nodes,
            source_rewriter,
            runtime_data
          )
        end
        fail 'No should_receive node is found!'
      end

      let(:runtime_data) { nil }

      let(:record) { should_receive_object.report.records.first }

      describe '#expectize!' do
        context 'when it is `subject.should_receive(:method)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo' do
                  subject.should_receive(:foo)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'receives #foo' do
                  expect(subject).to receive(:foo)
                end
              end
            END
          end

          it 'converts into `expect(subject).to receive(:method)` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record "`obj.should_receive(:message)` -> `expect(obj).to receive(:message)`"' do
            should_receive_object.expectize!
            record.original_syntax.should  == 'obj.should_receive(:message)'
            record.converted_syntax.should == 'expect(obj).to receive(:message)'
          end

          context 'and #expect and #receive are not available in the context' do
            context 'and the context is determinable statically' do
              let(:source) do
                <<-END
                  describe 'example' do
                    class TestRunner
                      def run
                        something = 'something'
                        something.should_receive(:foo)
                        something.foo
                      end
                    end

                    it 'receives #foo' do
                      TestRunner.new.run
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises InvalidContextError' do
                  -> { should_receive_object.expectize! }.should raise_error(InvalidContextError)
                end
              end

              context 'without runtime information' do
                it 'raises InvalidContextError' do
                  -> { should_receive_object.expectize! }.should raise_error(InvalidContextError)
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
                    it 'receives #foo' do
                      my_eval do
                        something = 'something'
                        something.should_receive(:foo)
                        something.foo
                      end
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises InvalidContextError' do
                  -> { should_receive_object.expectize! }.should raise_error(InvalidContextError)
                end
              end

              context 'without runtime information' do
                it 'does not raise InvalidContextError' do
                  -> { should_receive_object.expectize! }.should_not raise_error
                end
              end
            end
          end
        end

        context 'when it is `subject.should_not_receive(:method)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not receive #foo' do
                  subject.should_not_receive(:foo)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not receive #foo' do
                  expect(subject).not_to receive(:foo)
                end
              end
            END
          end

          it 'converts into `expect(subject).not_to receive(:method)` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`obj.should_not_receive(:message)` -> `expect(obj).not_to receive(:message)`"' do
            should_receive_object.expectize!
            record.original_syntax.should  == 'obj.should_not_receive(:message)'
            record.converted_syntax.should == 'expect(obj).not_to receive(:message)'
          end

          context 'and "to_not" is passed as negative form' do
            let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not receive #foo' do
                  expect(subject).to_not receive(:foo)
                end
              end
            END
            end

            it 'converts into `expect(subject).to_not receive(:method)` form' do
              should_receive_object.expectize!('to_not')
              rewritten_source.should == expected_source
            end

            it 'adds record ' +
               '"`obj.should_not_receive(:message)` -> `expect(obj).to_not receive(:message)`"' do
              should_receive_object.expectize!('to_not')
              record.original_syntax.should  == 'obj.should_not_receive(:message)'
              record.converted_syntax.should == 'expect(obj).to_not receive(:message)'
            end
          end
        end

        # Currently MessageExpectation#with supports the following syntax:
        #
        #   subject.should_receive(:foo).with do |arg|
        #     arg == 1
        #   end
        #
        # This syntax allows to expect arbitrary arguments without expect or should.
        # This is available only when #with got no normal arguments but a block,
        # and the block will not be used as a substitute implementation.
        #
        # https://github.com/rspec/rspec-mocks/blob/e6d1980/lib/rspec/mocks/message_expectation.rb#L307
        # https://github.com/rspec/rspec-mocks/blob/e6d1980/lib/rspec/mocks/argument_list_matcher.rb#L43
        #
        # Then, if you convert the example into expect syntax straightforward:
        #
        #   expect(subject).to receive(:foo).with do |arg|
        #     arg == 1
        #   end
        #
        # The do..end block is taken by the #to method, because {..} blocks have higher precedence
        # over do..end blocks. This behavior breaks the spec.
        #
        # To keep the same meaning of syntax, the block needs to be {..} form literal:
        #
        #   expect(subject).to receive(:foo).with { |arg|
        #     arg == 1
        #   }
        #
        context 'when it is `subject.should_receive(:method).with do .. end` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  subject.should_receive(:foo).with do |arg|
                    arg == 1
                  end
                  subject.foo(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  expect(subject).to receive(:foo).with { |arg|
                    arg == 1
                  }
                  subject.foo(1)
                end
              end
            END
          end

          it 'converts into `expect(subject).to receive(:method) { .. }` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        # If #with take normal arguments, the block won't be used as an argument matcher.
        context 'when it is `subject.should_receive(:method).with(arg) do .. end` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  subject.should_receive(:foo).with(1) do |arg|
                    do_some_substitute_implementation
                  end
                  subject.foo(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  expect(subject).to receive(:foo).with(1) do |arg|
                    do_some_substitute_implementation
                  end
                  subject.foo(1)
                end
              end
            END
          end

          it 'converts into `expect(subject).to receive(:method).with(arg) do .. end` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        # In this case, the do..end block is taken by the #should_receive method.
        # This means the receiver of #once method is return value of #should_receive,
        # that is actually an instance of RSpec::Mocks::MessageExpectation.
        #
        #   subject.should_receive(:foo) do |arg|
        #     arg == 1
        #   end.once
        #
        # However with `expect(subject).to receive`, the do..end block is taken by the #to method.
        # This means the receiver of #once method is return value of #to, that is actually
        # return value of RSpec::Mocks::Matchers::Receive#setup_method_substitute
        # and it's not the instance of RSpec::Mocks::MessageExpectation.
        #
        # https://github.com/rspec/rspec-mocks/blob/9cdef17/lib/rspec/mocks/targets.rb#L19
        # https://github.com/rspec/rspec-mocks/blob/9cdef17/lib/rspec/mocks/matchers/receive.rb#L74
        #
        # Then, the following syntax will be error:
        #
        #   expect(subject).to receive(:foo) do |arg|
        #     arg == 1
        #   end.once
        #
        # So the block needs to be {..} form literal also in this case.
        #
        #   expect(subject).to receive(:foo) { |arg|
        #     arg == 1
        #   }.once
        #
        context 'when it is `subject.should_receive(:method) do .. end.once` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  subject.should_receive(:foo) do |arg|
                    arg == 1
                  end.once
                  subject.foo(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  expect(subject).to receive(:foo) { |arg|
                    arg == 1
                  }.once
                  subject.foo(1)
                end
              end
            END
          end

          it 'converts into `expect(subject).to receive(:method) { .. }.once` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        # This case, do..end block works without problem.
        context 'when it is `subject.should_receive(:method) do .. end` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  subject.should_receive(:foo) do |arg|
                    expect(arg).to eq(1)
                  end
                  subject.foo(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'receives #foo with 1' do
                  expect(subject).to receive(:foo) do |arg|
                    expect(arg).to eq(1)
                  end
                  subject.foo(1)
                end
              end
            END
          end

          it 'converts into `expect(subject).to receive(:method) do .. end` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `SomeClass.any_instance.should_receive(:method)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo' do
                  SomeClass.any_instance.should_receive(:foo)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'receives #foo' do
                  expect_any_instance_of(SomeClass).to receive(:foo)
                end
              end
            END
          end

          it 'converts into `expect_any_instance_of(SomeClass).to receive(:method)` form' do
            should_receive_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record "`SomeClass.any_instance.should_receive(:message)` ' +
             '-> `expect_any_instance_of(SomeClass).to receive(:message)`"' do
            should_receive_object.expectize!
            record.original_syntax.should  == 'SomeClass.any_instance.should_receive(:message)'
            record.converted_syntax.should == 'expect_any_instance_of(SomeClass).to receive(:message)'
          end
        end
      end

      describe '#useless_expectation?' do
        subject { should_receive_object.useless_expectation? }

        context 'when it is `subject.should_receive(:method).any_number_of_times` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.should_receive(:foo).any_number_of_times
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `subject.should_receive(:method).with(arg).any_number_of_times` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo with 1' do
                  subject.should_receive(:foo).with(1).any_number_of_times
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `subject.should_receive(:method).at_least(0)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.should_receive(:foo).at_least(0)
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `subject.should_receive(:method).at_least(1)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives #foo at least once' do
                  subject.should_receive(:foo).with(1).at_least(1)
                end
              end
            END
          end

          it { should be_false }
        end

        context 'when it is `subject.should_receive(:method)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives to #foo' do
                  subject.should_receive(:foo)
                end
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#allowize_useless_expectation!' do
        context 'when it is `subject.should_receive(:method).any_number_of_times` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.should_receive(:foo).any_number_of_times
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  allow(subject).to receive(:foo)
                end
              end
            END
          end

          it 'converts into `allow(subject).to receive(:method)` form' do
            should_receive_object.allowize_useless_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`obj.should_receive(:message).any_number_of_times` -> `allow(obj).to receive(:message)`"' do
            should_receive_object.allowize_useless_expectation!
            record.original_syntax.should  == 'obj.should_receive(:message).any_number_of_times'
            record.converted_syntax.should == 'allow(obj).to receive(:message)'
          end

          context 'and #allow and #receive are not available in the context' do
            context 'and the context is determinable statically' do
              let(:source) do
                <<-END
                  describe 'example' do
                    class TestRunner
                      def run
                        'something'.should_receive(:foo).any_number_of_times
                      end
                    end

                    it 'responds to #foo' do
                      TestRunner.new.run
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises InvalidContextError' do
                  -> { should_receive_object.allowize_useless_expectation! }
                    .should raise_error(InvalidContextError)
                end
              end

              context 'without runtime information' do
                it 'raises InvalidContextError' do
                  -> { should_receive_object.allowize_useless_expectation! }
                    .should raise_error(InvalidContextError)
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
                      my_eval { 'something'.should_receive(:foo).any_number_of_times }
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises InvalidContextError' do
                  -> { should_receive_object.allowize_useless_expectation! }
                    .should raise_error(InvalidContextError)
                end
              end

              context 'without runtime information' do
                it 'does not raise InvalidContextError' do
                  -> { should_receive_object.allowize_useless_expectation! }
                    .should_not raise_error
                end
              end
            end
          end
        end

        context 'when it is `SomeClass.any_instance.should_receive(:method).any_number_of_times` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  SomeClass.any_instance.should_receive(:foo).any_number_of_times
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  allow_any_instance_of(SomeClass).to receive(:foo)
                end
              end
            END
          end

          it 'converts into `allow_any_instance_of(subject).to receive(:method)` form' do
            should_receive_object.allowize_useless_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`SomeClass.any_instance.should_receive(:message).any_number_of_times` ' +
             '-> `allow_any_instance_of(SomeClass).to receive(:message)`"' do
            should_receive_object.allowize_useless_expectation!
            record.original_syntax.should  == 'SomeClass.any_instance.should_receive(:message).any_number_of_times'
            record.converted_syntax.should == 'allow_any_instance_of(SomeClass).to receive(:message)'
          end
        end

        context 'when it is `subject.should_receive(:method).at_least(0)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.should_receive(:foo).at_least(0)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  allow(subject).to receive(:foo)
                end
              end
            END
          end

          it 'converts into `allow(subject).to receive(:method)` form' do
            should_receive_object.allowize_useless_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`obj.should_receive(:message).at_least(0)` -> `allow(obj).to receive(:message)`"' do
            should_receive_object.allowize_useless_expectation!
            record.original_syntax.should  == 'obj.should_receive(:message).at_least(0)'
            record.converted_syntax.should == 'allow(obj).to receive(:message)'
          end
        end

        context 'when it is `SomeClass.any_instance.should_receive(:method).at_least(0)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  SomeClass.any_instance.should_receive(:foo).at_least(0)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  allow_any_instance_of(SomeClass).to receive(:foo)
                end
              end
            END
          end

          it 'converts into `allow_any_instance_of(subject).to receive(:method)` form' do
            should_receive_object.allowize_useless_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`SomeClass.any_instance.should_receive(:message).at_least(0)` ' +
             '-> `allow_any_instance_of(SomeClass).to receive(:message)`"' do
            should_receive_object.allowize_useless_expectation!
            record.original_syntax.should  == 'SomeClass.any_instance.should_receive(:message).at_least(0)'
            record.converted_syntax.should == 'allow_any_instance_of(SomeClass).to receive(:message)'
          end
        end

        context 'when it is `subject.should_receive(:method)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives to #foo' do
                  subject.should_receive(:foo)
                end
              end
            END
          end

          it 'does nothing' do
            should_receive_object.allowize_useless_expectation!
            rewritten_source.should == source
          end
        end
      end

      describe '#stubize_useless_expectation!' do
        before do
          should_receive_object.stubize_useless_expectation!
        end

        context 'when it is `subject.should_receive(:method).any_number_of_times` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.should_receive(:foo).any_number_of_times
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo)
                end
              end
            END
          end

          it 'converts into `subject.stub(:method)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`obj.should_receive(:message).any_number_of_times` -> `obj.stub(:message)`"' do
            record.original_syntax.should  == 'obj.should_receive(:message).any_number_of_times'
            record.converted_syntax.should == 'obj.stub(:message)'
          end
        end

        context 'when it is `subject.should_receive(:method)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'receives to #foo' do
                  subject.should_receive(:foo)
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end
      end
    end
  end
end
