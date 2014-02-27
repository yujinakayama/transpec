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
              transpec_analyze((transpec_analyze((subject), self, "(string)_41_48", { :should_source_location => [:object, "method(:should).source_location"] }).should be(foo)), self, "(string)_41_63", { :expect_available? => [:context, "self.class.ancestors.any? { |a| a.name.start_with?('RSpec::') } && respond_to?(:expect)"] })
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
                transpec_analyze((transpec_analyze((subject), self, "(string)_53_60", { :should_source_location => [:object, "method(:should).source_location"] }).should), self, "(string)_53_67", { :"=~_source_location" => [:object, "method(:=~).source_location"], :expect_available? => [:context, "self.class.ancestors.any? { |a| a.name.start_with?('RSpec::') } && respond_to?(:expect)"] }) =~ transpec_analyze((<<-HEREDOC.gsub('foo', 'bar')), self, "(string)_71_100", { :arg_is_enumerable? => [:object, "is_a?(Enumerable)"] })
                foo
                HEREDOC
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
                transpec_analyze((expect { do_something }), self, "(string)_51_57", { :expect_source_location => [:context, "method(:expect).source_location"] }).to throw_symbol
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
                transpec_analyze((expect), self, "(string)_51_57", { :expect_source_location => [:context, "method(:expect).source_location"] })
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
                transpec_analyze((expect subject), self, "(string)_51_65", { :expect_source_location => [:context, "method(:expect).source_location"] })
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
