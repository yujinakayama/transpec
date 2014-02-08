# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/receive'
require 'transpec/syntax/expect'
require 'transpec/syntax/allow'

module Transpec
  class Syntax
    describe Receive do
      include_context 'parsed objects'
      include_context 'syntax object', Expect, :expect_object
      include_context 'syntax object', Allow, :allow_object

      let(:record) { receive_object.report.records.last }

      describe '#remove_useless_and_return!' do
        before do
          receive_object.remove_useless_and_return!
        end

        context 'with #expect' do
          let(:receive_object) { expect_object.receive_matcher }

          context 'when it is `expect(obj).to receive(:method).and_return { value }` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo and returns 1' do
                    expect(subject).to receive(:foo).and_return { 1 }
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'receives #foo and returns 1' do
                    expect(subject).to receive(:foo) { 1 }
                  end
                end
              END
            end

            it 'converts into `expect(obj).to receive(:method) { value }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return { value }` ' \
               '-> `expect(obj).to receive(:message) { value }`' do
              record.original_syntax.should  == 'expect(obj).to receive(:message).and_return { value }'
              record.converted_syntax.should == 'expect(obj).to receive(:message) { value }'
            end
          end

          context 'when it is `expect(obj).to receive(:method).and_return do value end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo and returns 1' do
                    expect(subject).to receive(:foo).and_return do
                      1
                    end
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'receives #foo and returns 1' do
                    expect(subject).to receive(:foo) do
                      1
                    end
                  end
                end
              END
            end

            it 'converts into `expect(obj).to receive(:method) do value end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return` ' \
               '-> `expect(obj).to receive(:message)`' do
              record.original_syntax.should  == 'expect(obj).to receive(:message).and_return'
              record.converted_syntax.should == 'expect(obj).to receive(:message)'
            end
          end

          context 'when it is `expect_any_instance_of(Klass).to receive(:method).and_return { value }` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo and returns 1' do
                    expect_any_instance_of(Klass).to receive(:foo).and_return { 1 }
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'receives #foo and returns 1' do
                    expect_any_instance_of(Klass).to receive(:foo) { 1 }
                  end
                end
              END
            end

            it 'converts into `expect_any_instance_of(Klass).to receive(:method) { value }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return` ' \
               '-> `expect(obj).to receive(:message)`' do
              record.original_syntax.should  == 'expect(obj).to receive(:message).and_return { value }'
              record.converted_syntax.should == 'expect(obj).to receive(:message) { value }'
            end
          end

          context 'when it is `expect(obj).to receive(:method).and_return` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    expect(subject).to receive(:foo).and_return
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    expect(subject).to receive(:foo)
                  end
                end
              END
            end

            it 'converts into `expect(obj).to receive(:method)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return` -> `expect(obj).to receive(:message)`' do
              record.original_syntax.should  == 'expect(obj).to receive(:message).and_return'
              record.converted_syntax.should == 'expect(obj).to receive(:message)'
            end
          end

          context 'when it is `expect(obj).to receive(:message).and_return(value)` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    expect(obj).to receive(:message).and_return(1)
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

        context 'with #allow' do
          let(:receive_object) { allow_object.receive_matcher }

          context 'when it is `allow(obj).to receive(:method).and_return { value }` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    allow(subject).to receive(:foo).and_return { 1 }
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo and returns 1' do
                    allow(subject).to receive(:foo) { 1 }
                  end
                end
              END
            end

            it 'converts into `allow(obj).to receive(:method) { value }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `allow(obj).to receive(:message).and_return { value }` ' \
               '-> `allow(obj).to receive(:message) { value }`' do
              record.original_syntax.should  == 'allow(obj).to receive(:message).and_return { value }'
              record.converted_syntax.should == 'allow(obj).to receive(:message) { value }'
            end
          end
        end
      end

      describe '#add_receiver_arg_to_any_instance_implementation_block!' do
        before do
          receive_object.add_receiver_arg_to_any_instance_implementation_block!
        end

        context 'with #expect' do
          let(:receive_object) { expect_object.receive_matcher }

          context 'when it is `expect_any_instance_of(Klass).to receive(:method) do |arg| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo) do |arg|
                    end
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo) do |instance, arg|
                    end
                  end
                end
              END
            end

            it 'converts into `expect_any_instance_of(Klass).to receive(:method) do |instance, arg| .. end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.original_syntax.should  == 'expect_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.converted_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'when it is `expect_any_instance_of(Klass).to receive(:method).once do |arg| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo).once do |arg|
                    end
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo).once do |instance, arg|
                    end
                  end
                end
              END
            end

            it 'converts into ' \
               '`expect_any_instance_of(Klass).to receive(:method).once do |instance, arg| .. end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.original_syntax.should  == 'expect_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.converted_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'when it is `expect_any_instance_of(Klass).to receive(:method) { |arg| .. }` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo) { |arg|
                    }
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo) { |instance, arg|
                    }
                  end
                end
              END
            end

            it 'converts into `expect_any_instance_of(Klass).to receive(:method) { |instance, arg| .. }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.original_syntax.should  == 'expect_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.converted_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'when it is `expect_any_instance_of(Klass).to receive(:method) do .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo) do
                    end
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end

          context 'when it is `expect_any_instance_of(Klass).to receive(:method) do |instance| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect_any_instance_of(Klass).to receive(:foo) do |instance|
                    end
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end

          context 'when it is `expect(subject).to receive(:method) do |arg| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'receives #foo' do
                    expect(subject).to receive(:foo) do |arg|
                    end
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end
        end

        context 'with #allow' do
          let(:receive_object) { allow_object.receive_matcher }

          context 'when it is `allow_any_instance_of(Klass).to receive(:method) do |arg| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo) do |arg|
                    end
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo) do |instance, arg|
                    end
                  end
                end
              END
            end

            it 'converts into `allow_any_instance_of(Klass).to receive(:method) do |instance, arg| .. end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `allow_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.original_syntax.should  == 'allow_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.converted_syntax.should == 'allow_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'when it is `allow_any_instance_of(Klass).to receive(:method) { |arg| .. }` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo) { |arg|
                    }
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo) { |instance, arg|
                    }
                  end
                end
              END
            end

            it 'converts into `allow_any_instance_of(Klass).to receive(:method) { |instance, arg| .. }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `allow_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.original_syntax.should  == 'allow_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.converted_syntax.should == 'allow_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'when it is `allow_any_instance_of(Klass).to receive(:method) do .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo) do
                    end
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end

          context 'when it is `allow_any_instance_of(Klass).to receive(:method) do |instance| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow_any_instance_of(Klass).to receive(:foo) do |instance|
                    end
                  end
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end

          context 'when it is `allow(subject).to receive(:method) do |arg| .. end` form' do
            let(:source) do
              <<-END
                describe 'example' do
                  it 'responds to #foo' do
                    allow(subject).to receive(:foo) do |arg|
                    end
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
end
