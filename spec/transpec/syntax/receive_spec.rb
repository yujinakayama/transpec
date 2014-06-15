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

          context 'with expression `expect(obj).to receive(:message).and_return { value }`' do
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

            it 'converts to `expect(obj).to receive(:message) { value }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return { value }` ' \
               '-> `expect(obj).to receive(:message) { value }`' do
              record.old_syntax.should == 'expect(obj).to receive(:message).and_return { value }'
              record.new_syntax.should == 'expect(obj).to receive(:message) { value }'
            end
          end

          context 'with expression `expect(obj).to receive(:message).and_return do value end`' do
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

            it 'converts to `expect(obj).to receive(:message) do value end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return` ' \
               '-> `expect(obj).to receive(:message)`' do
              record.old_syntax.should == 'expect(obj).to receive(:message).and_return'
              record.new_syntax.should == 'expect(obj).to receive(:message)'
            end
          end

          context 'with expression `expect_any_instance_of(Klass).to receive(:message).and_return { value }`' do
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

            it 'converts to `expect_any_instance_of(Klass).to receive(:message) { value }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return` ' \
               '-> `expect(obj).to receive(:message)`' do
              record.old_syntax.should == 'expect(obj).to receive(:message).and_return { value }'
              record.new_syntax.should == 'expect(obj).to receive(:message) { value }'
            end
          end

          context 'with expression `expect(obj).to receive(:message).and_return`' do
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

            it 'converts to `expect(obj).to receive(:message)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect(obj).to receive(:message).and_return` -> `expect(obj).to receive(:message)`' do
              record.old_syntax.should == 'expect(obj).to receive(:message).and_return'
              record.new_syntax.should == 'expect(obj).to receive(:message)'
            end
          end

          context 'with expression `expect(obj).to receive(:message).and_return(value)`' do
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

          context 'with expression `allow(obj).to receive(:message).and_return { value }`' do
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

            it 'converts to `allow(obj).to receive(:message) { value }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `allow(obj).to receive(:message).and_return { value }` ' \
               '-> `allow(obj).to receive(:message) { value }`' do
              record.old_syntax.should == 'allow(obj).to receive(:message).and_return { value }'
              record.new_syntax.should == 'allow(obj).to receive(:message) { value }'
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

          context 'with expression `expect_any_instance_of(Klass).to receive(:message) do |arg| .. end`' do
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

            it 'converts to `expect_any_instance_of(Klass).to receive(:message) do |instance, arg| .. end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.old_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.new_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'with expression `expect_any_instance_of(Klass).to receive(:message).once do |arg| .. end`' do
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

            it 'converts to ' \
               '`expect_any_instance_of(Klass).to receive(:message).once do |instance, arg| .. end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.old_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.new_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'with expression `expect_any_instance_of(Klass).to receive(:message) { |arg| .. }`' do
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

            it 'converts to `expect_any_instance_of(Klass).to receive(:message) { |instance, arg| .. }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `expect_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.old_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.new_syntax.should == 'expect_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'with expression `expect_any_instance_of(Klass).to receive(:message) do .. end`' do
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

          context 'with expression `expect_any_instance_of(Klass).to receive(:message) do |instance| .. end`' do
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

          context 'with expression `expect(obj).to receive(:message) do |arg| .. end`' do
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

          context 'with expression `allow_any_instance_of(Klass).to receive(:message) do |arg| .. end`' do
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

            it 'converts to `allow_any_instance_of(Klass).to receive(:message) do |instance, arg| .. end` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `allow_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.old_syntax.should == 'allow_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.new_syntax.should == 'allow_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'with expression `allow_any_instance_of(Klass).to receive(:message) { |arg| .. }`' do
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

            it 'converts to `allow_any_instance_of(Klass).to receive(:message) { |instance, arg| .. }` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record `allow_any_instance_of(Klass).to receive(:message) { |arg| }` ' \
               '-> `Klass.any_instance.should_receive(:message) { |instance, arg| }`' do
              record.old_syntax.should == 'allow_any_instance_of(Klass).to receive(:message) { |arg| }'
              record.new_syntax.should == 'allow_any_instance_of(Klass).to receive(:message) { |instance, arg| }'
            end
          end

          context 'with expression `allow_any_instance_of(Klass).to receive(:message) do .. end`' do
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

          context 'with expression `allow_any_instance_of(Klass).to receive(:message) do |instance| .. end`' do
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

          context 'with expression `allow(obj).to receive(:message) do |arg| .. end`' do
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
