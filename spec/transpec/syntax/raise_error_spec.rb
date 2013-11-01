# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/raise_error'

module Transpec
  class Syntax
    describe RaiseError do
      include_context 'parsed objects'

      subject(:raise_error_object) do
        ast.each_node do |node|
          next unless RaiseError.target_node?(node)
          return RaiseError.new(node, source_rewriter)
        end
        fail 'No raise_error node is found!'
      end

      let(:record) { raise_error_object.report.records.first }

      describe '#positive?' do
        subject { raise_error_object.positive? }

        context 'when it is `lambda { }.should raise_error` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  lambda { do_something }.should raise_error
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `expect { }.to raise_error` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  expect { do_something }.to raise_error
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `lambda { }.should raise_error { |error| ... }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  lambda { do_something }.should raise_error { |error| do_anything }
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `expect { }.to raise_error { |error| ... }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  expect { do_something }.to raise_error { |error| do_anything }
                end
              end
            END
          end

          it { should be_true }
        end

        context 'when it is `lambda { }.should_not raise_error` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  lambda { do_something }.should_not raise_error
                end
              end
            END
          end

          it { should be_false }
        end

        context 'when it is `expect { }.not_to raise_error` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error
                end
              end
            END
          end

          it { should be_false }
        end

        context 'when it is `expect { }.to_not raise_error` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.to_not raise_error
                end
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#remove_error_specification_with_negative_expectation!' do
        before do
          raise_error_object.remove_error_specification_with_negative_expectation!
        end

        context 'when it is `lambda { }.should raise_error(SpecificErrorClass)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises SpecificErrorClass' do
                  lambda { do_something }.should raise_error(SpecificErrorClass)
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end

          it 'reports nothing' do
            raise_error_object.report.records.should be_empty
          end
        end

        context 'when it is `expect { }.to raise_error(SpecificErrorClass)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises SpecificErrorClass' do
                  expect { do_something }.to raise_error(SpecificErrorClass)
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end

          it 'reports nothing' do
            raise_error_object.report.records.should be_empty
          end
        end

        context 'when it is `lambda { }.should raise_error(SpecificErrorClass) { |error| ... }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises SpecificErrorClass' do
                  lambda { do_something }.should raise_error(SpecificErrorClass) { |error| do_anything }
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end

          it 'reports nothing' do
            raise_error_object.report.records.should be_empty
          end
        end

        context 'when it is `expect { }.to raise_error(SpecificErrorClass) { |error| ... }` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'raises SpecificErrorClass' do
                  expect { do_something }.to raise_error(SpecificErrorClass) { |error| do_anything }
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end

          it 'reports nothing' do
            raise_error_object.report.records.should be_empty
          end
        end

        context 'when it is `lambda { }.should_not raise_error(SpecificErrorClass)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  lambda { do_something }.should_not raise_error(SpecificErrorClass)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  lambda { do_something }.should_not raise_error
                end
              end
            END
          end

          it 'converts into `lambda { }.should_not raise_error` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`expect { }.not_to raise_error(SpecificErrorClass)` -> `expect { }.not_to raise_error`\"' do
            record.original_syntax.should  == 'expect { }.not_to raise_error(SpecificErrorClass)'
            record.converted_syntax.should == 'expect { }.not_to raise_error'
          end
        end

        context 'when it is `expect { }.not_to raise_error(SpecificErrorClass)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error(SpecificErrorClass)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error
                end
              end
            END
          end

          it 'converts into `expect { }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `expect { }.to_not raise_error(SpecificErrorClass)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.to_not raise_error(SpecificErrorClass)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.to_not raise_error
                end
              end
            END
          end

          it 'converts into `expect { }.to_not raise_error` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`expect { }.not_to raise_error(SpecificErrorClass)` -> `expect { }.not_to raise_error`\"' do
            record.original_syntax.should  == 'expect { }.not_to raise_error(SpecificErrorClass)'
            record.converted_syntax.should == 'expect { }.not_to raise_error'
          end
        end

        context 'when it is `expect { }.not_to raise_error SpecificErrorClass` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error SpecificErrorClass
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error
                end
              end
            END
          end

          it 'converts into `expect { }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`expect { }.not_to raise_error(SpecificErrorClass)` -> `expect { }.not_to raise_error`\"' do
            record.original_syntax.should  == 'expect { }.not_to raise_error(SpecificErrorClass)'
            record.converted_syntax.should == 'expect { }.not_to raise_error'
          end
        end

        context 'when it is `expect { }.not_to raise_error(SpecificErrorClass, message)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error(SpecificErrorClass, message)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error
                end
              end
            END
          end

          it 'converts into `expect { }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`expect { }.not_to raise_error(SpecificErrorClass, message)` -> `expect { }.not_to raise_error`"' do
            record.original_syntax.should  == 'expect { }.not_to raise_error(SpecificErrorClass, message)'
            record.converted_syntax.should == 'expect { }.not_to raise_error'
          end
        end

        context 'when it is `expect { }.not_to raise_error(message)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error(message)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not raise error' do
                  expect { do_something }.not_to raise_error
                end
              end
            END
          end

          it 'converts into `expect { }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '"`expect { }.not_to raise_error(message)` -> `expect { }.not_to raise_error`"' do
            record.original_syntax.should  == 'expect { }.not_to raise_error(message)'
            record.converted_syntax.should == 'expect { }.not_to raise_error'
          end
        end
      end
    end
  end
end
