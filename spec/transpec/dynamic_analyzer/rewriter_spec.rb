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
            it 'matches to foo' do
              subject.should =~ foo
            end
          END
        end

        # rubocop:disable LineLength
        let(:expected_source) do
          <<-END
            it 'matches to foo' do
              transpec_analysis(subject, self, { :should_source_location => [:object, "method(:should).source_location"] }, __FILE__, 49, 56).should =~ transpec_analysis(foo, self, { :class_name => [:object, "self.class.name"] }, __FILE__, 67, 70)
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
                transpec_analysis(subject, self, { :should_source_location => [:object, "method(:should).source_location"] }, __FILE__, 53, 60).should =~ transpec_analysis((<<-HEREDOC.gsub('foo', 'bar')
                foo
                HEREDOC
                ), self, { :class_name => [:object, "self.class.name"] }, __FILE__, 71, 144)
              end
            END
          end
          # rubocop:enable LineLength

          it 'wraps the here document properly' do
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
