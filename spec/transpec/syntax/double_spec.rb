# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/double'

module Transpec
  class Syntax
    describe Double do
      include_context 'parsed objects'

      subject(:double_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless Double.conversion_target_node?(node)
          return Double.new(
            node,
            ancestor_nodes,
            source_rewriter
          )
        end
        fail 'No double node is found!'
      end

      describe '#method_name' do
        let(:source) do
          <<-END
            it 'includes something' do
              something = double('something')
              [1, something].should include(something)
            end
          END
        end

        it 'returns the method name' do
          double_object.method_name.should == :double
        end
      end

      describe '#convert_to_double!' do
        before do
          double_object.convert_to_double!
        end

        [:mock, :stub].each do |method|
          context "when it is ##{method}" do
            let(:source) do
              <<-END
                it 'includes something' do
                  something = #{method}('something')
                  [1, something].should include(something)
                end
              END
            end

            let(:expected_source) do
              <<-END
                it 'includes something' do
                  something = double('something')
                  [1, something].should include(something)
                end
              END
            end

            it 'replaces with #double' do
              rewritten_source.should == expected_source
            end

            it "adds record \"`#{method}('something')` -> `double('something')`\"" do
              record = double_object.report.records.first
              record.original_syntax.should  == "#{method}('something')"
              record.converted_syntax.should == "double('something')"
            end
          end
        end

        context 'when it is #double' do
          let(:source) do
            <<-END
              it 'includes something' do
                something = double('something')
                [1, something].should include(something)
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end

          it 'reports nothing' do
            double_object.report.records.should be_empty
          end
        end
      end
    end
  end
end
