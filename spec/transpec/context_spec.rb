# coding: utf-8

require 'spec_helper'
require 'transpec/context'

module Transpec
  describe Context do
    include ::AST::Sexp
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
      let(:context_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless node == s(:send, nil, :target)
          return Context.new(ancestor_nodes)
        end

        fail 'Target node not found!'
      end

      subject { context_object.in_example_group? }

      context 'when in top level' do
        let(:source) do
          'target'
        end

        it { should be_false }
      end

      context 'when in an instance method in top level' do
        let(:source) do
          <<-END
            def some_method
              target
            end
          END
        end

        it { should be_true }
      end

      context 'when in a block in an instance method in top level' do
        let(:source) do
          <<-END
            def some_method
              1.times do
                target
              end
            end
          END
        end

        it { should be_true }
      end

      context 'when in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              target
            end
          END
        end

        it { should be_false }
      end

      context 'when in an instance method in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              def some_method
                target
              end
            end
          END
        end

        it { should be_true }
      end

      context 'when in a block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              it 'is an example' do
                target
              end
            end
          END
        end

        it { should be_true }
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

       it { should be_false }
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
              end
            end
          END
        end

        it { should be_false }
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

        it { should be_false }
      end

      context 'when in an instance method in #describe block in a module' do
        let(:source) do
          <<-END
            module SomeModule
              describe 'foo' do
                def some_method
                  target
                end
              end
            end
          END
        end

        it { should be_true }
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

        it { should be_true }
      end

      context 'when in an instance method in a module' do
        let(:source) do
          <<-END
            module SomeModule
              def some_method
                target
              end
            end
          END
        end

        # Instance methods of module can be used by `include SomeModule` in #describe block.
        it { should be_true }
      end

      context 'when in an instance method in a class' do
        let(:source) do
          <<-END
            class SomeClass
              def some_method
                target
              end
            end
          END
        end

        it { should be_false }
      end

      context 'when in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              target
            end
          END
        end

        it { should be_false }
      end

      context 'when in a block in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              config.before do
                target
              end
            end
          END
        end

        it { should be_true }
      end

      context 'when in an instance method in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              def some_method
                target
              end
            end
          END
        end

        it { should be_true }
      end
    end
  end
end
