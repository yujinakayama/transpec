# coding: utf-8

require 'spec_helper'
require 'transpec/context'

module Transpec
  describe Context do
    include_context 'parsed objects'

    def node_id(node)
      id = node.type.to_s
      node.children.each do |child|
        break if child.is_a?(Parser::AST::Node)
        id << " #{child.inspect}"
      end
      id
    end

    describe '#scopes' do
      let(:source) do
        <<-END
          some_var = 1

          RSpec.configure do |config|
            config.before do
              prepare_something
            end
          end

          module SomeModule
            SOME_CONST = 1

            describe 'something' do
              def some_method(some_arg)
                do_something
              end

              it 'is 1' do
                something.should == 1
              end
            end
          end
        END
      end

      it 'returns scope stack' do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          expected_scopes = begin
            case node_id(node)
            when 'lvasgn :some_var'
              []
            when 'send nil :prepare_something'
              [:rspec_configure, :block]
            when 'module'
              []
            when 'const nil :SomeModule'
              # [:module] # TODO
            when 'casgn nil :SOME_CONST'
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
            when 'send nil :something'
              [:module, :example_group, :block]
            end
          end

          # TODO: Some scope nodes have special child nodes
          #   such as their arguments or their subject.
          #   But from scope point of view, the child nodes are not in the parent's scope,
          #   they should be in the next outer scope.

          next unless expected_scopes

          context_object = Context.new(ancestor_nodes)
          context_object.scopes.should == expected_scopes
        end
      end
    end

    describe '#in_example_group?' do
      let(:source) do
        <<-END
          top

          def some_method
            imethod_top

            1.times do
              block_imethod_top
            end
          end

          describe 'foo' do
            describe_top

            def some_method
              imethod_describe_top
            end

            it 'is an example' do
              block_describe_top

              class SomeClass
                class_block_describe_top

                def some_method
                  imethod_class_block_describe_top
                end
              end
            end
          end

          module SomeModule
            describe 'bar' do
              describe_module

              def some_method
                imethod_describe_module
              end

              it 'is an example' do
                block_describe_module
              end
            end
          end

          module AnotherModule
            def some_method
              imethod_module
            end
          end

          class SomeClass
            def some_method
              imethod_class
            end
          end

          RSpec.configure do |config|
            rspecconfigure

            def some_method
              imethod_rspecconfigure
            end

            config.before do
              block_rspecconfigure
            end
          end
        END
      end

      let(:context_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless node_id(node) == target_node_id
          return Context.new(ancestor_nodes)
        end

        fail 'Target node not found!'
      end

      subject { context_object.in_example_group? }

      context 'when in top level' do
        let(:target_node_id) { 'send nil :top' }
        it { should be_false }
      end

      context 'when in an instance method in top level' do
        let(:target_node_id) { 'send nil :imethod_top' }
        it { should be_true }
      end

      context 'when in a block in an instance method in top level' do
        let(:target_node_id) { 'send nil :block_imethod_top' }
        it { should be_true }
      end

      context 'when in #describe block in top level' do
        let(:target_node_id) { 'send nil :describe_top' }
        it { should be_false }
      end

      context 'when in an instance method in #describe block in top level' do
        let(:target_node_id) { 'send nil :imethod_describe_top' }
        it { should be_true }
      end

      context 'when in a block in #describe block in top level' do
        let(:target_node_id) { 'send nil :block_describe_top' }
        it { should be_true }
      end

      context 'when in a class in a block in #describe block' do
        let(:target_node_id) { 'send nil :class_block_describe_top' }
        it { should be_false }
      end

      context 'when in an instance method in a class in a block in #describe block' do
        let(:target_node_id) { 'send nil :imethod_class_block_describe_top' }
        it { should be_false }
      end

      context 'when in #describe block in a module' do
        let(:target_node_id) { 'send nil :describe_module' }
        it { should be_false }
      end

      context 'when in an instance method in #describe block in a module' do
        let(:target_node_id) { 'send nil :imethod_describe_module' }
        it { should be_true }
      end

      context 'when in a block in #describe block in a module' do
        let(:target_node_id) { 'send nil :block_describe_module' }
        it { should be_true }
      end

      context 'when in an instance method in a module' do
        # Instance methods of module can be used by `include SomeModule` in #describe block.
        let(:target_node_id) { 'send nil :imethod_module' }
        it { should be_true }
      end

      context 'when in an instance method in a class' do
        let(:target_node_id) { 'send nil :imethod_class' }
        it { should be_false }
      end

      context 'when in RSpec.configure' do
        let(:target_node_id) { 'send nil :rspecconfigure' }
        it { should be_false }
      end

      context 'when in a block in RSpec.configure' do
        let(:target_node_id) { 'send nil :block_rspecconfigure' }
        it { should be_true }
      end

      context 'when in an instance method in RSpec.configure' do
        let(:target_node_id) { 'send nil :imethod_rspecconfigure' }
        it { should be_true }
      end
    end
  end
end
