# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/be_close'

module Transpec
  class Syntax
    describe BeClose do
      include_context 'parsed objects'

      subject(:be_close_object) do
        ast.each_node do |node|
          next unless BeClose.target_node?(node)
          return BeClose.new(node, source_rewriter)
        end
        fail 'No be_close node is found!'
      end

      describe '#convert_to_be_within!' do
        before do
          be_close_object.convert_to_be_within!
        end

        context 'when it is `be_close(expected, delta)` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is close to 0.333' do
                  (1.0 / 3.0).should be_close(0.333, 0.001)
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'is close to 0.333' do
                  (1.0 / 3.0).should be_within(0.001).of(0.333)
                end
              end
            END
          end

          it 'converts into `be_within(delta).of(expected)` form' do
            rewritten_source.should == expected_source
          end

          it 'adds record "`be_close(expected, delta)` -> `be_within(delta).of(expected)`"' do
            record = be_close_object.report.records.first
            record.original_syntax.should  == 'be_close(expected, delta)'
            record.converted_syntax.should == 'be_within(delta).of(expected)'
          end
        end
      end
    end
  end
end
