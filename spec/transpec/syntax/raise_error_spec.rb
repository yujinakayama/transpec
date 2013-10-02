# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/raise_error'

module Transpec
  class Syntax
    describe RaiseError do
      include_context 'parsed objects'

      subject(:raise_error_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless RaiseError.target_node?(node)
          return RaiseError.new(
            node,
            ancestor_nodes,
            source_rewriter
          )
        end
        fail 'No raise_error node is found!'
      end

      describe '#remove_error_specification_with_negative_expectation!' do
        before do
          raise_error_object.remove_error_specification_with_negative_expectation!
        end

        context 'when it is `lambda { ... }.should raise_error(SomeErrorClass)` form' do
          let(:source) do
            <<-END
              it 'raises SomeErrorClass' do
                lambda { do_something }.should raise_error(SomeErrorClass)
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'when it is `expect { ... }.to raise_error(SomeErrorClass)` form' do
          let(:source) do
            <<-END
              it 'raises SomeErrorClass' do
                expect { do_something }.to raise_error(SomeErrorClass)
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'when it is `lambda { ... }.should_not raise_error(SomeErrorClass)` form' do
          let(:source) do
            <<-END
              it 'does not raise error' do
                lambda { do_something }.should_not raise_error(SomeErrorClass)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'does not raise error' do
                lambda { do_something }.should_not raise_error
              end
            END
          end

          it 'converts into `lambda { ... }.should_not raise_error` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `expect { ... }.not_to raise_error(SomeErrorClass)` form' do
          let(:source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error(SomeErrorClass)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error
              end
            END
          end

          it 'converts into `expect { ... }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `expect { ... }.to_not raise_error(SomeErrorClass)` form' do
          let(:source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.to_not raise_error(SomeErrorClass)
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.to_not raise_error
              end
            END
          end

          it 'converts into `expect { ... }.to_not raise_error` form' do
            rewritten_source.should == expected_source
          end
        end

        context 'when it is `expect { ... }.not_to raise_error SomeErrorClass` form' do
          let(:source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error SomeErrorClass
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error
              end
            END
          end

          it 'converts into `expect { ... }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end
        end

        context "when it is `expect { ... }.not_to raise_error(SomeErrorClass, 'message')` form" do
          let(:source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error(SomeErrorClass, 'message')
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error
              end
            END
          end

          it 'converts into `expect { ... }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end
        end

        context "when it is `expect { ... }.not_to raise_error(nil, 'message')` form" do
          let(:source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error(nil, 'message')
              end
            END
          end

          let(:expected_source) do
            <<-END
              it 'does not raise error' do
                expect { do_something }.not_to raise_error
              end
            END
          end

          it 'converts into `expect { ... }.not_to raise_error` form' do
            rewritten_source.should == expected_source
          end
        end
      end
    end
  end
end
