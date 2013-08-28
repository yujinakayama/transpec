# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/be_close'

module Transpec
  class Syntax
    describe BeClose do
      include_context 'parsed objects'

      subject(:be_close_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless BeClose.target_node?(node)
          return BeClose.new(
            node,
            ancestor_nodes,
            in_example_group_context?,
            source_rewriter
          )
        end
        fail 'No be_close node is found!'
      end

      let(:in_example_group_context?) { true }

      describe '#convert_to_be_within!' do
        let(:source) do
          <<-END
            it 'is close to 0.333' do
              (1.0 / 3.0).should be_close(0.333, 0.001)
            end
          END
        end

        let(:expected_source) do
          <<-END
            it 'is close to 0.333' do
              (1.0 / 3.0).should be_within(0.001).of(0.333)
            end
          END
        end

        it 'converts into `be_within(delta).of(expected)` form' do
          be_close_object.convert_to_be_within!
          rewritten_source.should == expected_source
        end
      end
    end
  end
end
