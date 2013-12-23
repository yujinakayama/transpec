# coding: utf-8

require 'spec_helper'
require 'transpec/dynamic_analyzer/rewriter'

module Transpec
  class DynamicAnalyzer
    describe Rewriter do
      include ::AST::Sexp

      subject(:rewriter) { Rewriter.new }

      describe '#rewrite' do
        subject { rewriter.rewrite(source) }

        let(:source) do
          <<-END
            it 'is foo' do
              subject.should be(foo)
            end
          END
        end

        # rubocop:disable LineLength
        let(:expected_source) do
          <<-END
            it 'is foo' do
              transpec_analysis((transpec_analysis((subject), self, { :should_source_location => [:object, "method(:should).source_location"] }, __FILE__, 41, 48).should be(foo)), self, { :expect_available? => [:context, "self.class.ancestors.any? { |a| a.name.start_with?('RSpec::') } && respond_to?(:expect)"] }, __FILE__, 41, 63)
            end
          END
        end
        # rubocop:enable LineLength

        it 'wraps target object with analysis helper method' do
          should == expected_source
        end

        context 'when the target includes here document' do
          let(:source) do
            <<-END
              it 'matches to foo' do
                subject.should =~ <<-HEREDOC.gsub('foo', 'bar')
                foo
                HEREDOC
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              it 'matches to foo' do
                transpec_analysis((transpec_analysis((subject), self, { :should_source_location => [:object, "method(:should).source_location"] }, __FILE__, 53, 60).should), self, { :"=~_source_location" => [:object, "method(:=~).source_location"], :expect_available? => [:context, "self.class.ancestors.any? { |a| a.name.start_with?('RSpec::') } && respond_to?(:expect)"] }, __FILE__, 53, 67) =~ transpec_analysis((<<-HEREDOC.gsub('foo', 'bar')
                foo
                HEREDOC
                ), self, { :arg_is_enumerable? => [:object, "is_a?(Enumerable)"] }, __FILE__, 71, 144)
              end
            END
          end
          # rubocop:enable LineLength

          it 'wraps the here document properly' do
            should == expected_source
          end
        end

        context 'when the target takes block' do
          let(:source) do
            <<-END
              it 'raises error' do
                expect { do_something }.to throw_symbol
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              it 'raises error' do
                transpec_analysis((expect { do_something }), self, { :expect_source_location => [:context, "method(:expect).source_location"] }, __FILE__, 51, 57).to throw_symbol
              end
            END
          end
          # rubocop:enable LineLength

          it 'wraps the block properly' do
            should == expected_source
          end
        end

        context 'when the target is only the expression in a block' do
          let(:source) do
            <<-END
              it 'raises error' do
                expect
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              it 'raises error' do
                transpec_analysis((expect), self, { :expect_source_location => [:context, "method(:expect).source_location"] }, __FILE__, 51, 57)
              end
            END
          end
          # rubocop:enable LineLength

          it 'wraps the target properly' do
            should == expected_source
          end
        end

        context 'when the target is method invocation without parentheses' do
          let(:source) do
            <<-END
              it 'raises error' do
                expect subject
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              it 'raises error' do
                transpec_analysis((expect subject), self, { :expect_source_location => [:context, "method(:expect).source_location"] }, __FILE__, 51, 65)
              end
            END
          end
          # rubocop:enable LineLength

          it 'wraps the target properly' do
            should == expected_source
          end
        end
      end

      describe '#register_request' do
        let(:some_node) { s(:int, 1) }
        let(:another_node) { s(:int, 2) }

        it 'stores requests for each node' do
          rewriter.register_request(some_node, :odd, 'odd?', :object)
          rewriter.register_request(another_node, :even, 'even?', :object)
          rewriter.requests.should == {
            some_node    => { odd: [:object, 'odd?'] },
            another_node => { even: [:object, 'even?'] }
          }
        end

        it 'merges multiple requests for same node' do
          rewriter.register_request(some_node, :odd, 'odd?', :object)
          rewriter.register_request(some_node, :even, 'even?', :object)
          rewriter.requests.should == {
            some_node => { odd: [:object, 'odd?'], even: [:object, 'even?'] }
          }
        end
      end
    end
  end
end
