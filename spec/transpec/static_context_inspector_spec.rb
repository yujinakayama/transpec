# coding: utf-8

require 'spec_helper'
require 'transpec/static_context_inspector'

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
              in_normal_block
            end
          end
        END
      end

      it 'returns scope stack' do
        ast.each_node do |node|
          expected_scopes = begin
            case node_id(node)
            when 'send nil :top_level'
              []
            when 'send nil :in_before'
              [:rspec_configure, :each_before_after]
            when 'module'
              []
            when 'const nil :SomeModule'
              # [:module] # TODO
            when 'send nil :in_module'
              [:module]
            when 'send nil :describe'
              # [:module] # TODO
            when 'def :some_method'
              [:module, :example_group]
            when 'arg :some_arg'
              # [:module, :example_group] # TODO
            when 'send nil :do_something'
              [:module, :example_group, :def]
            when 'send nil :it'
              # [:module, :example_group] # TODO
            when 'str "is 1"'
              # [:module, :example_group] # TODO
            when 'send nil :in_example'
              [:module, :example_group, :example]
            when 'send nil :in_normal_block'
              [:module]
            end
          end

          # TODO: Some scope nodes have special child nodes
          #   such as their arguments or their subject.
          #   But from scope point of view, the child nodes are not in the parent's scope,
          #   they should be in the next outer scope.

          next unless expected_scopes

          context_inspector = StaticContextInspector.new(node)
          context_inspector.scopes.should == expected_scopes
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
        # Clear SPEC_OPTS environment variable so that this spec does not fail
        # with dynamic analysis in self-testing.
        original_spec_opts = ENV['SPEC_OPTS']
        ENV['SPEC_OPTS'] = nil

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
      ensure
        ENV['SPEC_OPTS'] = original_spec_opts
      end

      describe '#non_monkey_patch_expectation_available?' do
        subject { context_inspector.non_monkey_patch_expectation_available? }

        let(:expected) do
          eval_source = 'respond_to?(:expect)'
          with_cache(eval_source + source) do
            eval_with_rspec_in_context(eval_source, source)
          end
        end

        it { should == expected }
      end

      describe '#non_monkey_patch_mock_available?' do
        subject { context_inspector.non_monkey_patch_mock_available? }

        let(:expected) do
          eval_source = 'respond_to?(:allow) && respond_to?(:receive)'
          with_cache(eval_source + source) do
            eval_with_rspec_in_context(eval_source, source)
          end
        end

        it { should == expected }
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
              class SomeClass
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
              class SomeClass
                def some_method
                  target
                end
              end

              SomeClass.new.some_method
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
          class SomeClass
            def some_method
              target
            end
          end

          describe 'test' do
            example { SomeClass.new.some_method }
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
