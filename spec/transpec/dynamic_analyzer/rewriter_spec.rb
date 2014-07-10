# coding: utf-8

require 'spec_helper'
require 'transpec/dynamic_analyzer/rewriter'

module Transpec
  class DynamicAnalyzer
    describe Rewriter do
      include ::AST::Sexp

      subject(:rewriter) { Rewriter.new }

      describe '#rewrite_source' do
        subject { rewriter.rewrite_source(source) }

        let(:source) do
          <<-END
            subject.should be(foo)
          END
        end

        # rubocop:disable LineLength
        let(:expected_source) do
          <<-'END'
            Transpec.analyze((Transpec.analyze((subject), self, "(string)_12_19", { :should_source_location => [:object, "method(:should).source_location"], :should_example_method_defined_by_user? => [:object, "owner = method(:should).owner\nowner != RSpec::Core::ExampleGroup &&\n  owner.ancestors.include?(RSpec::Core::ExampleGroup)"] }).should be(foo)), self, "(string)_12_34", { :expect_available? => [:context, "self.class.ancestors.any? { |a| a.name.start_with?('RSpec::') } && respond_to?(:expect)"] })
          END
        end
        # rubocop:enable LineLength

        it 'wraps target object with analysis helper method' do
          should == expected_source
        end

        context 'when the target includes here document' do
          let(:source) do
            <<-END
              subject.should =~ <<-HEREDOC.gsub('foo', 'bar')
              foo
              HEREDOC
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-'END'
              Transpec.analyze((Transpec.analyze((subject), self, "(string)_14_21", { :should_source_location => [:object, "method(:should).source_location"], :should_example_method_defined_by_user? => [:object, "owner = method(:should).owner\nowner != RSpec::Core::ExampleGroup &&\n  owner.ancestors.include?(RSpec::Core::ExampleGroup)"] }).should), self, "(string)_14_28", { :expect_available? => [:context, "self.class.ancestors.any? { |a| a.name.start_with?('RSpec::') } && respond_to?(:expect)"], :"=~_source_location" => [:object, "method(:=~).source_location"], :"=~_example_method_defined_by_user?" => [:object, "owner = method(:=~).owner\nowner != RSpec::Core::ExampleGroup &&\n  owner.ancestors.include?(RSpec::Core::ExampleGroup)"] }) =~ Transpec.analyze((<<-HEREDOC.gsub('foo', 'bar')), self, "(string)_32_61", { :enumerable_arg? => [:object, "is_a?(Enumerable)"] })
              foo
              HEREDOC
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
              expect { do_something }.to throw_symbol
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-'END'
              Transpec.analyze((expect { do_something }), self, "(string)_14_20", { :expect_source_location => [:context, "method(:expect).source_location"], :expect_example_method_defined_by_user? => [:context, "owner = method(:expect).owner\nowner != RSpec::Core::ExampleGroup &&\n  owner.ancestors.include?(RSpec::Core::ExampleGroup)"] }).to throw_symbol
            END
          end
          # rubocop:enable LineLength

          it 'wraps the block properly' do
            should == expected_source
          end
        end

        context 'when the target is method invocation without parentheses' do
          let(:source) do
            <<-END
              double 'something'
            END
          end

          # rubocop:disable LineLength
          let(:expected_source) do
            <<-'END'
              Transpec.analyze((double 'something'), self, "(string)_14_32", { :double_source_location => [:context, "method(:double).source_location"], :double_example_method_defined_by_user? => [:context, "owner = method(:double).owner\nowner != RSpec::Core::ExampleGroup &&\n  owner.ancestors.include?(RSpec::Core::ExampleGroup)"] })
            END
          end
          # rubocop:enable LineLength

          it 'wraps the target properly' do
            should == expected_source
          end
        end
      end

      describe '#register_request' do
        include_context 'parsed objects'

        let(:source) do
          <<-END
            1
            2
          END
        end

        let(:a_node) { ast.children[0] }
        let(:another_node) { ast.children[1] }

        it 'stores requests for each node' do
          rewriter.register_request(a_node, :odd, 'odd?', :object)
          rewriter.register_request(another_node, :even, 'even?', :object)
          rewriter.requests[a_node].should == { odd: [:object, 'odd?'] }
          rewriter.requests[another_node].should == { even: [:object, 'even?'] }
        end

        it 'merges multiple requests for same node' do
          rewriter.register_request(a_node, :odd, 'odd?', :object)
          rewriter.register_request(a_node, :even, 'even?', :object)
          rewriter.requests[a_node].should == { odd: [:object, 'odd?'], even: [:object, 'even?'] }
        end

        context 'when there are same structure nodes but they are not identical objects' do
          let(:source) do
            <<-END
              1
              1
            END
          end

          it 'properly diffrenciate them' do
            rewriter.register_request(a_node, :odd, 'odd?', :object)
            rewriter.register_request(another_node, :even, 'even?', :object)
            rewriter.requests[a_node].should == { odd: [:object, 'odd?'] }
            rewriter.requests[another_node].should == { even: [:object, 'even?'] }
          end
        end
      end
    end
  end
end
