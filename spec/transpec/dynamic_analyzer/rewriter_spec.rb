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
              transpec_analysis(subject, { :should_source_location => "method(:should).source_location" }, self, __FILE__, 49, 56).should =~ transpec_analysis(foo, { :class_name => "self.class.name" }, self, __FILE__, 67, 70)
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
                transpec_analysis(subject, { :should_source_location => "method(:should).source_location" }, self, __FILE__, 53, 60).should =~ transpec_analysis((<<-HEREDOC.gsub('foo', 'bar')
                foo
                HEREDOC
                ), { :class_name => "self.class.name" }, self, __FILE__, 71, 144)
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
          rewriter.register_request(some_node, :odd, 'odd?')
          rewriter.register_request(another_node, :even, 'even?')
          rewriter.requests.should == {
            some_node    => { odd: 'odd?' },
            another_node => { even: 'even?' }
          }
        end

        it 'merges multiple requests for same node' do
          rewriter.register_request(some_node, :odd, 'odd?')
          rewriter.register_request(some_node, :even, 'even?')
          rewriter.requests.should == {
            some_node => { odd: 'odd?', even: 'even?' }
          }
        end
      end
    end
  end
end
