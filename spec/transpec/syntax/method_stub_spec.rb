# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/method_stub'

module Transpec
  class Syntax
    describe MethodStub do
      include_context 'parsed objects'

      subject(:method_stub_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes, in_example_group_context|
          next unless MethodStub.target_node?(node)
          return MethodStub.new(
            node,
            ancestor_nodes,
            source_rewriter
          )
        end
        fail 'No method stub node is found!'
      end

      let(:record) { method_stub_object.report.records.first }

      describe '.target_node?' do
        let(:send_node) do
          ast.each_descendent_node do |node|
            next unless node.type == :send
            method_name = node.children[1]
            next unless method_name == :stub
            return node
          end
          fail 'No #stub node is found!'
        end

        context 'when #stub node is passed' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo)
              end
            END
          end

          it 'returns true' do
            MethodStub.target_node?(send_node).should be_true
          end
        end

        context 'when #stub node with Typhoeus receiver is passed' do
          let(:source) do
            <<-END
              it "is not RSpec's #stub" do
                ::Typhoeus.stub(url, :method => method).and_return(response)
              end
            END
          end

          it 'returns false' do
            MethodStub.target_node?(send_node).should be_false
          end
        end

        context 'when #stub node with Excon receiver is passed' do
          let(:source) do
            <<-END
              it "is not RSpec's #stub" do
                ::Excon.stub({}, {:body => 'body', :status => 200})
              end
            END
          end

          it 'returns false' do
            MethodStub.target_node?(send_node).should be_false
          end
        end
      end

      describe '#method_name' do
        let(:source) do
          <<-END
            it 'responds to #foo' do
              subject.stub(:foo)
            end
          END
        end

        it 'returns the method name' do
          method_stub_object.method_name.should == :stub
        end
      end

      describe '#allowize!' do
        before do
          method_stub_object.context.stub(:allow_to_receive_available?).and_return(true)
          method_stub_object.allowize!
        end

        [:stub, :stub!].each do |method|
          context "when it is `subject.#{method}(:method)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo' do
                  subject.#{method}(:foo)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo' do
                  allow(subject).to receive(:foo)
                end
              END
            end

            it 'converts into `allow(subject).to receive(:method)` form' do
              rewritten_source.should == expected_source
            end

            it "adds record \"`obj.#{method}(:message)` -> `allow(obj).to receive(:message)`\"" do
              record.original_syntax.should  == "obj.#{method}(:message)"
              record.converted_syntax.should == 'allow(obj).to receive(:message)'
            end
          end

          context "when it is `subject.#{method}(:method).and_return(value)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  subject.#{method}(:foo).and_return(1)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(:foo).and_return(1)
                end
              END
            end

            it 'converts into `allow(subject).to receive(:method).and_return(value)` form' do
              rewritten_source.should == expected_source
            end
          end

          context "when it is `subject.#{method}(:method).and_raise(RuntimeError)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo and raises RuntimeError' do
                  subject.#{method}(:foo).and_raise(RuntimeError)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo and raises RuntimeError' do
                  allow(subject).to receive(:foo).and_raise(RuntimeError)
                end
              END
            end

            it 'converts into `allow(subject).to receive(:method).and_raise(RuntimeError)` form' do
              rewritten_source.should == expected_source
            end
          end

          context 'when the statement continues over multi lines' do
            let(:source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  subject.#{method}(
                      :foo
                    ).
                    and_return(
                      1
                    )
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(
                      :foo
                    ).
                    and_return(
                      1
                    )
                end
              END
            end

            it 'keeps the style as far as possible' do
              rewritten_source.should == expected_source
            end
          end

          context "when it is `subject.#{method}(:method => value)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  subject.#{method}(:foo => 1)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(:foo).and_return(1)
                end
              END
            end

            it 'converts into `allow(subject).to receive(:method).and_return(value)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record ' +
               "\"`obj.#{method}(:message => value)` -> `allow(obj).to receive(:message).and_return(value)`\"" do
              record.original_syntax.should  == "obj.#{method}(:message => value)"
              record.converted_syntax.should == 'allow(obj).to receive(:message).and_return(value)'
            end
          end

          context "when it is `subject.#{method}(method: value)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  subject.#{method}(foo: 1)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo and returns 1' do
                  allow(subject).to receive(:foo).and_return(1)
                end
              END
            end

            it 'converts into `allow(subject).to receive(:method).and_return(value)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record ' +
               "\"`obj.#{method}(:message => value)` -> `allow(obj).to receive(:message).and_return(value)`\"" do
              record.original_syntax.should  == "obj.#{method}(:message => value)"
              record.converted_syntax.should == 'allow(obj).to receive(:message).and_return(value)'
            end
          end

          context "when it is `subject.#{method}(:a_method => a_value, b_method => b_value)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                  subject.#{method}(:foo => 1, :bar => 2)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                  allow(subject).to receive(:foo).and_return(1)
                  allow(subject).to receive(:bar).and_return(2)
                end
              END
            end

            it 'converts into `allow(subject).to receive(:a_method).and_return(a_value)` ' +
               'and `allow(subject).to receive(:b_method).and_return(b_value)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record ' +
               "\"`obj.#{method}(:message => value)` -> `allow(obj).to receive(:message).and_return(value)`\"" do
              record.original_syntax.should  == "obj.#{method}(:message => value)"
              record.converted_syntax.should == 'allow(obj).to receive(:message).and_return(value)'
            end

            context 'when the statement continues over multi lines' do
              let(:source) do
                <<-END
                  it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                    subject
                      .#{method}(
                        :foo => 1,
                        :bar => 2
                      )
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  it 'responds to #foo and returns 1, and responds to #bar and returns 2' do
                    allow(subject)
                      .to receive(:foo).and_return(1)
                    allow(subject)
                      .to receive(:bar).and_return(2)
                  end
                END
              end

              it 'keeps the style except around the hash' do
                rewritten_source.should == expected_source
              end
            end
          end
        end

        [:unstub, :unstub!].each do |method|
          context "when it is `subject.#{method}(:method)` form" do
            let(:source) do
              <<-END
                it 'does not respond to #foo' do
                  subject.#{method}(:foo)
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

        [:stub, :stub!].each do |method|
          context "when it is `SomeClass.any_instance.#{method}(:method)` form" do
            let(:source) do
              <<-END
                it 'responds to #foo' do
                  SomeClass.any_instance.#{method}(:foo)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'responds to #foo' do
                  allow_any_instance_of(SomeClass).to receive(:foo)
                end
              END
            end

            it 'converts into `allow_any_instance_of(SomeClass).to receive(:method)` form' do
              rewritten_source.should == expected_source
            end

            it "adds record \"`SomeClass.any_instance.#{method}(:message)` " +
               '-> `allow_any_instance_of(obj).to receive(:message)`"' do
              record.original_syntax.should  == "SomeClass.any_instance.#{method}(:message)"
              record.converted_syntax.should == 'allow_any_instance_of(SomeClass).to receive(:message)'
            end
          end
        end

        [:unstub, :unstub!].each do |method|
          context "when it is `SomeClass.any_instance.#{method}(:method)` form" do
            let(:source) do
              <<-END
                it 'does not respond to #foo' do
                  SomeClass.any_instance.#{method}(:foo)
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

      describe '#replace_deprecated_method!' do
        before do
          method_stub_object.replace_deprecated_method!
        end

        [
          [:stub!,   :stub,   'responds to'],
          [:unstub!, :unstub, 'does not respond to']
        ].each do |method, replacement_method, description|
          context "when it is ##{method}" do
            let(:source) do
              <<-END
                it '#{description} #foo' do
                  subject.#{method}(:foo)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it '#{description} #foo' do
                  subject.#{replacement_method}(:foo)
                end
              END
            end

            it "replaces with ##{replacement_method}" do
              rewritten_source.should == expected_source
            end

            it 'adds record ' +
               "\"`obj.#{method}(:message)` -> `obj.#{replacement_method}(:message)`\"" do
              record.original_syntax.should  == "obj.#{method}(:message)"
              record.converted_syntax.should == "obj.#{replacement_method}(:message)"
            end
          end
        end

        [
          [:stub,   'responds to'],
          [:unstub, 'does not respond to']
        ].each do |method, description|
          context "when it is ##{method}" do
            let(:source) do
              <<-END
                it '#{description} #foo' do
                  subject.#{method}(:foo)
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

        context 'when it is `subject.stub(:method).any_number_of_times` form' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo).any_number_of_times
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `subject.stub(:method).with(arg).any_number_of_times` form' do
          let(:source) do
            <<-END
              it 'responds to #foo with 1' do
                subject.stub(:foo).with(1).any_number_of_times
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `subject.stub(:method).at_least(0)` form' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo).at_least(0)
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `subject.stub(:method)` form' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo)
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#remove_allowance_for_no_message!' do
        before do
          method_stub_object.remove_allowance_for_no_message!
        end

        context 'when it is `subject.stub(:method).any_number_of_times` form' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo).any_number_of_times
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo)
              end
            END
          end

          it 'removes `.any_number_of_times`' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `subject.stub(:method).at_least(0)` form' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo).at_least(0)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo)
              end
            END
          end

          it 'removes `.at_least(0)`' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `subject.stub(:method)` form' do
          let(:source) do
            <<-END
              it 'responds to #foo' do
                subject.stub(:foo)
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
