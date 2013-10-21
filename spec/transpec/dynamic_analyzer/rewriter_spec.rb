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
            describe 'example' do
              it 'matches to foo' do
                subject.should =~ foo
              end
            end
          END
        end

        # rubocop:disable LineLength
        let(:expected_source) do
          <<-END
            describe 'example' do
              it 'matches to foo' do
                transpec_analysis((subject), self, { :should_source_location => [:object, "method(:should).source_location"] }, __FILE__, 87, 94).should =~ transpec_analysis((foo), self, { :class_name => [:object, "self.class.name"] }, __FILE__, 105, 108)
              end
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
              describe 'example' do
                it 'matches to foo' do
                  subject.should =~ <<-HEREDOC.gsub('foo', 'bar')
                  foo
                  HEREDOC
                end
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'matches to foo' do
                  transpec_analysis((subject), self, { :should_source_location => [:object, "method(:should).source_location"] }, __FILE__, 93, 100).should =~ transpec_analysis((<<-HEREDOC.gsub('foo', 'bar')
                  foo
                  HEREDOC
                  ), self, { :class_name => [:object, "self.class.name"] }, __FILE__, 111, 188)
                end
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
              describe 'example' do
                it 'raises error' do
                  expect { do_something }.to throw_symbol
                end
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  transpec_analysis((expect { do_something }), self, { :expect_source_location => [:context, "method(:expect).source_location"] }, __FILE__, 91, 97).to throw_symbol
                end
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
              describe 'example' do
                it 'raises error' do
                  expect
                end
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  transpec_analysis((expect), self, { :expect_source_location => [:context, "method(:expect).source_location"] }, __FILE__, 91, 97)
                end
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
              describe 'example' do
                it 'raises error' do
                  expect subject
                end
              end
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'raises error' do
                  transpec_analysis((expect subject), self, { :expect_source_location => [:context, "method(:expect).source_location"] }, __FILE__, 91, 105)
                end
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
