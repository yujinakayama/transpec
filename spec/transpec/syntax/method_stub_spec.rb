# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/method_stub'
require 'transpec'

module Transpec
  class Syntax
    describe MethodStub do
      include_context 'parsed objects'
      include_context 'syntax object', MethodStub, :method_stub_object

      let(:record) { method_stub_object.report.records.first }

      describe '#conversion_target?' do
        let(:target_node) do
          ast.each_node(:send).find do |send_node|
            method_name = send_node.children[1]
            method_name == :stub
          end
        end

        let(:method_stub_object) do
          MethodStub.new(target_node, source_rewriter, runtime_data)
        end

        subject { method_stub_object.conversion_target? }

        context 'when #stub node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo)
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when Factory.stub node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                it "is not RSpec's #stub" do
                  Factory.stub(:foo)
                end
              end
            END
          end

          it { should be_false }
        end

        context 'with runtime information' do
          include_context 'dynamic analysis objects'

          context "when RSpec's #stub node is passed" do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    subject.stub(:foo)
                  end
                end
              END
            end

            it { should be_true }
          end

          context 'when another #stub node is passed' do
            let(:source) do
              <<-END
                module AnotherStubProvider
                  def self.stub(*args)
                  end
                end

                describe 'example' do
                  it "is not RSpec's #stub" do
                    AnotherStubProvider.stub(:something)
                  end
                end
              END
            end

            it { should be_false }
          end

          context "when Factory.stub node is passed and it's RSpec's #stub" do
            let(:source) do
              <<-END
                module Factory
                end

                describe 'example' do
                  it 'responds to #foo' do
                    Factory.stub(:foo)
                  end
                end
              END
            end

            it { should be_true }
          end

          context 'when Factory.stub node is passed and it has not been run' do
            let(:source) do
              <<-END
                module Factory
                end

                describe 'example' do
                  it 'responds to #foo' do
                    true || Factory.stub(:foo)
                  end
                end
              END
            end

            it { should be_false }
          end
        end
      end

      describe '#method_name' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'responds to #foo' do
                subject.stub(:foo)
              end
            end
          END
        end

        it 'returns the method name' do
          method_stub_object.method_name.should == :stub
        end
      end

      describe '#hash_arg?' do
        subject { method_stub_object.hash_arg? }

        context 'with expression `obj.stub(:message => value)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo => value)
                end
              end
            END
          end

          it { should be_true }
        end

        context 'with expression `obj.stub(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo)
                end
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#allowize!' do
        before do
          method_stub_object.allowize!(rspec_version) unless example.metadata[:no_before_allowize!]
        end

        let(:rspec_version) { Transpec.required_rspec_version }

        context 'with expression `obj.stub(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo)
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

          it 'converts to `allow(obj).to receive(:message)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.stub(:message)` -> `allow(obj).to receive(:message)`' do
            record.old_syntax.should == 'obj.stub(:message)'
            record.new_syntax.should == 'allow(obj).to receive(:message)'
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            it 'converts to `allow(obj).to receive(:message)` form' do
              rewritten_source.should == expected_source
            end
          end

          context 'and #allow and #receive are not available in the context', :no_before_allowize! do
            context 'and the context is determinable statically' do
              let(:source) do
                <<-END
                  describe 'example' do
                    class TestRunner
                      def run
                        'something'.stub(:foo)
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

                it 'raises ContextError' do
                  -> { method_stub_object.allowize!(rspec_version) }
                    .should raise_error(ContextError)
                end
              end

              context 'without runtime information' do
                it 'raises ContextError' do
                  -> { method_stub_object.allowize!(rspec_version) }
                    .should raise_error(ContextError)
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
                      my_eval { 'something'.stub(:foo) }
                    end
                  end
                END
              end

              context 'with runtime information' do
                include_context 'dynamic analysis objects'

                it 'raises ContextError' do
                  -> { method_stub_object.allowize!(rspec_version) }
                    .should raise_error(ContextError)
                end
              end

              context 'without runtime information' do
                it 'does not raise ContextError' do
                  -> { method_stub_object.allowize!(rspec_version) }
                    .should_not raise_error
                end
              end
            end
          end
        end

        context 'with expression `obj.stub!(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub!(:foo)
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

          it 'converts to `allow(obj).to receive(:message)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.stub!(:message)` -> `allow(obj).to receive(:message)`' do
            record.old_syntax.should == 'obj.stub!(:message)'
            record.new_syntax.should == 'allow(obj).to receive(:message)'
          end
        end

        context 'with expression `obj.stub(:message).and_return(value)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo).and_return(1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(:foo).and_return(1)
                end
              end
            END
          end

          it 'converts to `allow(obj).to receive(:message).and_return(value)` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `obj.stub(:message).and_raise(RuntimeError)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and raises RuntimeError' do
                  subject.stub(:foo).and_raise(RuntimeError)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and raises RuntimeError' do
                  allow(subject).to receive(:foo).and_raise(RuntimeError)
                end
              end
            END
          end

          it 'converts to `allow(obj).to receive(:message).and_raise(RuntimeError)` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when the statement continues over multi lines' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(
                      :foo
                    ).
                    and_return(
                      1
                    )
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(
                      :foo
                    ).
                    and_return(
                      1
                    )
                end
              end
            END
          end

          it 'keeps the style as far as possible' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `obj.stub(:message => value)`' do
          context 'and #receive_messages is available' do
            # #before here does not work because #allowized! is invoked in super #before.
            let(:rspec_version) do
              rspec_version = Transpec.required_rspec_version
              rspec_version.stub(:receive_messages_available?).and_return(true)
              rspec_version
            end

            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    subject.stub(:foo => 1)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    allow(subject).to receive_messages(:foo => 1)
                  end
                end
              END
            end

            it 'converts to `allow(obj).to receive_messages(:message => value)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record ' \
               '`obj.stub(:message => value)` -> `allow(obj).to receive_messages(:message => value)`' do
              record.old_syntax.should == 'obj.stub(:message => value)'
              record.new_syntax.should == 'allow(obj).to receive_messages(:message => value)'
            end
          end

          context 'and #receive_messages is not available' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    subject.stub(:foo => 1)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    allow(subject).to receive(:foo).and_return(1)
                  end
                end
              END
            end

            it 'converts to `allow(obj).to receive(:message).and_return(value)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record ' \
               '`obj.stub(:message => value)` -> `allow(obj).to receive(:message).and_return(value)`' do
              record.old_syntax.should == 'obj.stub(:message => value)'
              record.new_syntax.should == 'allow(obj).to receive(:message).and_return(value)'
            end
          end
        end

        context 'with expression `obj.stub(method: value)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(foo: 1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(:foo).and_return(1)
                end
              end
            END
          end

          it 'converts to `allow(obj).to receive(:message).and_return(value)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`obj.stub(:message => value)` -> `allow(obj).to receive(:message).and_return(value)`' do
            record.old_syntax.should == 'obj.stub(:message => value)'
            record.new_syntax.should == 'allow(obj).to receive(:message).and_return(value)'
          end
        end

        context 'with expression `obj.stub(:a_method => a_value, b_method => b_value)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                  subject.stub(:foo => 1, :bar => 2)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                  allow(subject).to receive(:foo).and_return(1)
                  allow(subject).to receive(:bar).and_return(2)
                end
              end
            END
          end

          it 'converts to `allow(obj).to receive(:a_method).and_return(a_value)` ' \
             'and `allow(obj).to receive(:b_method).and_return(b_value)`' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`obj.stub(:message => value)` -> `allow(obj).to receive(:message).and_return(value)`' do
            record.old_syntax.should == 'obj.stub(:message => value)'
            record.new_syntax.should == 'allow(obj).to receive(:message).and_return(value)'
          end

          context 'when the statement continues over multi lines' do
            context 'and #receive_messages is available' do
              # #before here does not work because #allowized! is invoked in super #before.
              let(:rspec_version) do
                rspec_version = Transpec.required_rspec_version
                rspec_version.stub(:receive_messages_available?).and_return(true)
                rspec_version
              end

              let(:source) do
                <<-END
                  describe 'example' do
                    it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                      subject
                        .stub(
                          :foo => 1,
                          :bar => 2
                        )
                    end
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  describe 'example' do
                    it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                      allow(subject)
                        .to receive_messages(
                          :foo => 1,
                          :bar => 2
                        )
                    end
                  end
                END
              end

              it 'keeps the style' do
                rewritten_source.should == expected_source
              end
            end

            context 'and #receive_messages is not available' do
              let(:source) do
                <<-END
                  describe 'example' do
                    it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                      subject
                        .stub(
                          :foo => 1,
                          :bar => 2
                        )
                    end
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  describe 'example' do
                    it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                      allow(subject)
                        .to receive(:foo).and_return(1)
                      allow(subject)
                        .to receive(:bar).and_return(2)
                    end
                  end
                END
              end

              it 'keeps the style except around the hash' do
                rewritten_source.should == expected_source
              end
            end
          end
        end

        context 'with expression `obj.stub_chain(:foo, :bar => value)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to .foo.bar and returns 1' do
                  subject.stub_chain(:foo, :bar => 1)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to .foo.bar and returns 1' do
                  allow(subject).to receive_message_chain(:foo, :bar => 1)
                end
              end
            END
          end

          context 'and #receive_message_chain is available' do
            # #before here does not work because #allowized! is invoked in super #before.
            let(:rspec_version) do
              rspec_version = Transpec.required_rspec_version
              rspec_version.stub(:receive_message_chain_available?).and_return(true)
              rspec_version
            end

            it 'converts to `allow(obj).to receive_message_chain(:foo, :bar => value)` form' do
              rewritten_source.should == expected_source
            end

            it "adds record `obj.stub_chain(:message1, :message2)` -> ' +
               '`allow(obj).to receive_message_chain(:message1, :message2)`" do
              record.old_syntax.should == 'obj.stub_chain(:message1, :message2)'
              record.new_syntax.should == 'allow(obj).to receive_message_chain(:message1, :message2)'
            end
          end

          context 'and #receive_message_chain is not available' do
            it 'does nothing' do
              rewritten_source.should == source
            end
          end
        end

        [:unstub, :unstub!].each do |method|
          context "with expression `obj.#{method}(:message)`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'does not respond to #foo' do
                    subject.#{method}(:foo)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'does not respond to #foo' do
                    allow(subject).to receive(:foo).and_call_original
                  end
                end
              END
            end

            it 'converts to `allow(subject).to receive(:method).and_call_original`' do
              rewritten_source.should == expected_source
            end

            it "adds record `obj.#{method}(:message)` -> `allow(obj).to receive(:message).and_call_original`" do
              record.old_syntax.should == "obj.#{method}(:message)"
              record.new_syntax.should == 'allow(obj).to receive(:message).and_call_original'
            end
          end
        end

        context 'with expression `obj.unstub :message`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not respond to #foo' do
                  subject.unstub :foo
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not respond to #foo' do
                  allow(subject).to receive(:foo).and_call_original
                end
              end
            END
          end

          it 'converts to `allow(subject).to receive(:method).and_call_original`' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `Klass.any_instance.stub(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  Klass.any_instance.stub(:foo)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  allow_any_instance_of(Klass).to receive(:foo)
                end
              end
            END
          end

          it 'converts to `allow_any_instance_of(Klass).to receive(:message)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `Klass.any_instance.stub(:message)` ' \
             '-> `allow_any_instance_of(obj).to receive(:message)`' do
            record.old_syntax.should == 'Klass.any_instance.stub(:message)'
            record.new_syntax.should == 'allow_any_instance_of(Klass).to receive(:message)'
          end

          context 'when the statement continues over multi lines' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    Klass
                      .any_instance
                        .stub(
                          :foo
                        ).
                        and_return(
                          1
                        )
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    allow_any_instance_of(Klass)
                        .to receive(
                          :foo
                        ).
                        and_return(
                          1
                        )
                  end
                end
              END
            end

            it 'keeps the style as far as possible' do
              rewritten_source.should == expected_source
            end
          end
        end

        context 'with expression `described_class.any_instance.stub(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  described_class.any_instance.stub(:foo)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  allow_any_instance_of(described_class).to receive(:foo)
                end
              end
            END
          end

          it 'converts to `allow_any_instance_of(described_class).to receive(:message)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `Klass.any_instance.stub(:message)` ' \
             '-> `allow_any_instance_of(obj).to receive(:message)`' do
            record.old_syntax.should == 'Klass.any_instance.stub(:message)'
            record.new_syntax.should == 'allow_any_instance_of(Klass).to receive(:message)'
          end
        end

        context 'with expression `variable.any_instance.stub(:message)` ' \
                'and the variable is an AnyInstance::Recorder' do
          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    variable = String.any_instance
                    variable.stub(:foo)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    variable = String.any_instance
                    allow_any_instance_of(String).to receive(:foo)
                  end
                end
              END
            end

            it 'converts to `allow_any_instance_of(Klass).to receive(:message)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `Klass.any_instance.stub(:message)` ' \
               '-> `allow_any_instance_of(obj).to receive(:message)`' do
              record.old_syntax.should == 'Klass.any_instance.stub(:message)'
              record.new_syntax.should == 'allow_any_instance_of(Klass).to receive(:message)'
            end
          end
        end

        [:unstub, :unstub!].each do |method|
          context "with expression `Klass.any_instance.#{method}(:message)`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'does not respond to #foo' do
                    Klass.any_instance.#{method}(:foo)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'does not respond to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo).and_call_original
                  end
                end
              END
            end

            it 'converts to `allow(subject).to receive(:method).and_call_original`' do
              rewritten_source.should == expected_source
            end

            it "adds record `Klass.any_instance.#{method}(:message)` " \
               '-> `allow_any_instance_of(Klass).to receive(:message).and_call_original`' do
              record.old_syntax.should == "Klass.any_instance.#{method}(:message)"
              record.new_syntax.should == 'allow_any_instance_of(Klass).to receive(:message).and_call_original'
            end
          end
        end
      end

      describe '#convert_deprecated_method!' do
        before do
          method_stub_object.convert_deprecated_method!
        end

        [
          [:stub!,   :stub,   'responds to'],
          [:unstub!, :unstub, 'does not respond to']
        ].each do |method, replacement_method, description|
          context "with expression `obj.#{method}(:message)`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it '#{description} #foo' do
                    subject.#{method}(:foo)
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it '#{description} #foo' do
                    subject.#{replacement_method}(:foo)
                  end
                end
              END
            end

            it "converts to `obj.##{replacement_method}(:message)`" do
              rewritten_source.should == expected_source
            end

            it 'adds record ' \
               "`obj.#{method}(:message)` -> `obj.#{replacement_method}(:message)`" do
              record.old_syntax.should == "obj.#{method}(:message)"
              record.new_syntax.should == "obj.#{replacement_method}(:message)"
            end
          end
        end

        [
          [:stub,   'responds to'],
          [:unstub, 'does not respond to']
        ].each do |method, description|
          context "with expression `obj.#{method}(:message)`" do
            let(:source) do
              <<-END
                describe 'example' do
                  it '#{description} #foo' do
                    subject.#{method}(:foo)
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end

            it 'reports nothing' do
              method_stub_object.report.records.should be_empty
            end
          end
        end
      end

      describe '#allow_no_message?' do
        subject { method_stub_object.allow_no_message? }

        context 'with expression `obj.stub(:message).any_number_of_times`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo).any_number_of_times
                end
              end
            END
          end

          it { should be_true }
        end

        context 'with expression `obj.stub(:message).with(arg).any_number_of_times`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo with 1' do
                  subject.stub(:foo).with(1).any_number_of_times
                end
              end
            END
          end

          it { should be_true }
        end

        context 'with expression `obj.stub(:message).at_least(0)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo).at_least(0)
                end
              end
            END
          end

          it { should be_true }
        end

        context 'with expression `obj.stub(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo)
                end
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#remove_no_message_allowance!' do
        before do
          method_stub_object.remove_no_message_allowance!
        end

        context 'with expression `obj.stub(:message).any_number_of_times`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo).any_number_of_times
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

          it 'removes `.any_number_of_times`' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`obj.stub(:message).any_number_of_times` -> `obj.stub(:message)`' do
            record.old_syntax.should == 'obj.stub(:message).any_number_of_times'
            record.new_syntax.should == 'obj.stub(:message)'
          end
        end

        context 'with expression `obj.stub(:message).at_least(0)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo).at_least(0)
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

          it 'removes `.at_least(0)`' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`obj.stub(:message).at_least(0)` -> `obj.stub(:message)`' do
            record.old_syntax.should == 'obj.stub(:message).at_least(0)'
            record.new_syntax.should == 'obj.stub(:message)'
          end
        end

        context 'with expression `obj.stub(:message)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo)
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end
      end

      describe '#remove_useless_and_return!' do
        before do
          method_stub_object.remove_useless_and_return!
        end

        context 'with expression `obj.stub(:message).and_return { value }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo).and_return { 1 }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo) { 1 }
                end
              end
            END
          end

          it 'converts to `obj.stub(:message) { value }` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.stub(:message).and_return { value }` -> `obj.stub(:message) { value }`' do
            record.old_syntax.should == 'obj.stub(:message).and_return { value }'
            record.new_syntax.should == 'obj.stub(:message) { value }'
          end
        end

        context 'with multiline expression `obj.stub(:message)\n.and_return { value }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo)
                    .and_return { 1 }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo) { 1 }
                end
              end
            END
          end

          it 'converts to `obj.stub(:message) { value }` form' \
             'while preventing the block from being interpreted as a hash' do
            rewritten_source.should == expected_source
          end
        end

        context 'with multiline expression `obj.stub(:message).\nand_return { value }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo).
                    and_return { 1 }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo) { 1 }
                end
              end
            END
          end

          it 'converts to `obj.stub(:message) { value }` form' \
             'while preventing the block from being interpreted as a hash' do
            rewritten_source.should == expected_source
          end
        end

        context 'with expression `obj.stub(:message).and_return`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  subject.stub(:foo).and_return
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

          it 'converts to `obj.stub(:message)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `obj.stub(:message).and_return` -> `obj.stub(:message)`' do
            record.old_syntax.should == 'obj.stub(:message).and_return'
            record.new_syntax.should == 'obj.stub(:message)'
          end
        end

        context 'with expression `obj.stub(:message).and_return(value)`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo and returns 1' do
                  subject.stub(:foo).and_return(1)
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
            record.should be_nil
          end
        end
      end

      describe '#add_receiver_arg_to_any_instance_implementation_block!' do
        before do
          method_stub_object.add_receiver_arg_to_any_instance_implementation_block!
        end

        context 'with expression `Klass.any_instance.stub(:message) do |arg| .. end`' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  Klass.any_instance.stub(:foo) do |arg|
                  end
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'responds to #foo' do
                  Klass.any_instance.stub(:foo) do |instance, arg|
                  end
                end
              end
            END
          end

          it 'converts to `Klass.any_instance.stub(:message) do |instance, arg| .. end` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record `Klass.any_instance.stub(:message) { |arg| }` ' \
             '-> `Klass.any_instance.stub(:message) { |instance, arg| }`' do
            record.old_syntax.should == 'Klass.any_instance.stub(:message) { |arg| }'
            record.new_syntax.should == 'Klass.any_instance.stub(:message) { |instance, arg| }'
          end
        end
      end
    end
  end
end
