# coding: utf-8

require 'spec_helper'
require 'transpec/static_context_inspector'
require 'ast'

module Transpec
  describe StaticContextInspector do
    include CacheHelper
    include ::AST::Sexp
    include_context 'parsed objects'
    include_context 'isolated environment'

    describe '#scopes' do
      def node_id(node)
        id = node.type.to_s
        node.children.each do |child|
          break if child.is_a?(Parser::AST::Node)
          id << " #{child.inspect}"
        end
        id
      end

      let(:source) do
        <<-END
          top_level

          RSpec.configure do |config|
            config.before do
              in_before
            end
          end

          module SomeModule
            in_module

            describe 'something' do
              def some_method(some_arg)
                do_something
              end

              it 'is 1' do
                in_example
              end
            end

            1.times do
              in_block
            end
          end

          feature 'Capybara DSL' do
            background do
              in_background
            end

            given(:foo) do
              in_given
            end

            scenario 'some page shows something' do
              in_scenario
            end
          end
        END
      end

      [
        [
          'send nil :top_level',
          'in top level',
          []
        ], [
          'send nil :in_before',
          'in before block in RSpec.configure',
          [:rspec_configure, :each_before_after]
        ], [
          'module',
          'at module definition in top level',
          []
        ], [
          'const nil :SomeModule',
          'at constant of module definition',
          []
        ], [
          'send nil :in_module',
          'in module',
          [:module]
        ], [
          'send nil :describe',
          'at #describe in module',
          [:module]
        ], [
          'def :some_method',
          'at method definition in #describe in module',
          [:module, :example_group]
        ], [
          'arg :some_arg',
          'at method argument in #describe in module',
          [:module, :example_group, :def]
        ], [
          'send nil :do_something',
          'in method in #describe in module',
          [:module, :example_group, :def]
        ], [
          'send nil :it',
          'at #it in #describe in module',
          [:module, :example_group]
        ], [
          'str "is 1"',
          "at #it's description in #describe in module",
          [:module, :example_group]
        ], [
          'send nil :in_example',
          '#it in #describe in module',
          [:module, :example_group, :example]
        ], [
          'send nil :in_block',
          'in normal block in #describe in module',
          [:module]
        ], [
          'send nil :in_background',
          'in #background block in #feature',
          [:example_group, :each_before_after]
        ], [
          'send nil :in_given',
          'in #given block in #feature',
          [:example_group, :helper]
        ], [
          'send nil :in_scenario',
          'in #scenario block in #feature',
          [:example_group, :example]
        ]
      ].each  do |target_node_id, description, expected_scopes|
        context "when #{description}" do
          let(:target_node) do
            ast.each_node.find do |node|
              node_id(node) == target_node_id
            end
          end

          it "returns #{expected_scopes.inspect}" do
            fail 'Target node is not found!' unless target_node

            context_inspector = StaticContextInspector.new(target_node)
            context_inspector.scopes.should == expected_scopes
          end
        end
      end
    end

    shared_examples 'context inspection methods' do
      let(:context_inspector) do
        ast.each_node do |node|
          next unless node == s(:send, nil, :target)
          return StaticContextInspector.new(node)
        end

        fail 'Target node not found!'
      end

      def eval_with_rspec_in_context(eval_source, spec_source)
        result_path = 'result'

        helper_source = <<-END
          def target
            File.open(#{result_path.inspect}, 'w') do |file|
              Marshal.dump(#{eval_source}, file)
            end
          end
        END

        source_path = 'spec.rb'

        File.write(source_path, helper_source + spec_source)

        `rspec #{source_path}`

        Marshal.load(File.read(result_path))
      end

      describe '#non_monkey_patch_expectation_available?' do
        subject { context_inspector.non_monkey_patch_expectation_available? }

        let(:expected) do
          eval_source = 'respond_to?(:expect)'
          with_cache(eval_source + source) do
            eval_with_rspec_in_context(eval_source, source)
          end
        end

        it { should be expected }
      end

      describe '#non_monkey_patch_mock_available?' do
        subject { context_inspector.non_monkey_patch_mock_available? }

        let(:expected) do
          eval_source = 'respond_to?(:allow) && respond_to?(:receive)'
          with_cache(eval_source + source) do
            eval_with_rspec_in_context(eval_source, source)
          end
        end

        it { should be expected }
      end
    end

    context 'when in top level' do
      let(:source) do
        'target'
      end

      include_examples 'context inspection methods'
    end

    context 'when in an instance method in top level' do
      let(:source) do
        <<-END
          def some_method
            target
          end

          describe('test') { example { target } }
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in a block in an instance method in top level' do
      let(:source) do
        <<-END
          def some_method
            1.times do
              target
            end
          end

          describe('test') { example { target } }
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            target
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in an instance method in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            def some_method
              target
            end

            example { some_method }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #it block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            it 'is an example' do
              target
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #before block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            before do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #before(:each) block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            before(:each) do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #before(:all) block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            before(:all) do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #after block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            after do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #after(:each) block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            after(:each) do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #after(:all) block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            after(:all) do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #around block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            around do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #subject block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            subject do
              target
            end

            example { subject }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #subject! block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            subject! do
              target
            end

            example { subject }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #let block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            let(:something) do
              target
            end

            example { something }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #let! block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            let!(:something) do
              target
            end

            example { something }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in any other block in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            1.times do
              target
            end

            example { }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #before block in singleton method with self in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            def self.some_method
              before do
                target
              end
            end

            some_method

            example { something }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #before block in singleton method with other object in #describe block in top level' do
      let(:source) do
        <<-END
          describe 'foo' do
            some_object = 'some object'

            def some_object.before
              yield
            end

            def some_object.some_method
              before do
                target
              end
            end

            some_object.some_method
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in a class in a block in #describe block' do
      let(:source) do
        <<-END
          describe 'foo' do
            it 'is an example' do
              class Klass
                target
              end
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in an instance method in a class in a block in #describe block' do
      let(:source) do
        <<-END
          describe 'foo' do
            it 'is an example' do
              class Klass
                def some_method
                  target
                end
              end

              Klass.new.some_method
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #describe block in a module' do
      let(:source) do
        <<-END
          module SomeModule
            describe 'foo' do
              target
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in an instance method in #describe block in a module' do
      let(:source) do
        <<-END
          module SomeModule
            describe 'foo' do
              def some_method
                target
              end

              example { some_method }
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in a block in #describe block in a module' do
      let(:source) do
        <<-END
          module SomeModule
            describe 'foo' do
              it 'is an example' do
                target
              end
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in an instance method in a module' do
      let(:source) do
        <<-END
          module SomeModule
            def some_method
              target
            end
          end

          describe 'test' do
            include SomeModule
            example { some_method }
          end
        END
      end

      # Instance methods of module can be used by `include SomeModule` in #describe block.
      include_examples 'context inspection methods'
    end

    context 'when in an instance method in a class' do
      let(:source) do
        <<-END
          class Klass
            def some_method
              target
            end
          end

          describe 'test' do
            example { Klass.new.some_method }
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in RSpec.configure' do
      let(:source) do
        <<-END
          RSpec.configure do |config|
            target
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in #before block in RSpec.configure' do
      let(:source) do
        <<-END
          RSpec.configure do |config|
            config.before do
              target
            end
          end

          describe('test') { example { } }
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in a normal block in RSpec.configure' do
      let(:source) do
        <<-END
          RSpec.configure do |config|
            1.times do
              target
            end
          end
        END
      end

      include_examples 'context inspection methods'
    end

    context 'when in an instance method in RSpec.configure' do
      let(:source) do
        <<-END
          RSpec.configure do |config|
            def some_method
              target
            end
          end

          describe('test') { example { some_method } }
        END
      end

      include_examples 'context inspection methods'
    end
  end
end
