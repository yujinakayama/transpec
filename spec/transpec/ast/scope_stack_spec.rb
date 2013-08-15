# coding: utf-8

require 'spec_helper'
require 'transpec/ast/scope_stack'

module Transpec
  module AST
    describe ScopeStack do
      describe '#in_example_group_context?' do
        subject { ScopeStack.new(scopes).in_example_group_context? }

        context 'when in top level' do
          let(:scopes) { [] }
          it { should be_false }
        end

        context 'when in an instance method in top level' do
          let(:scopes) { [:def] }
          it { should be_true }
        end

        context 'when in a block in an instance method in top level' do
          let(:scopes) { [:def, :block] }
          it { should be_true }
        end

        context 'when in #describe block in top level' do
          let(:scopes) { [:example_group] }
          it { should be_false }
        end

        context 'when in #describe block in a module' do
          let(:scopes) { [:module, :example_group] }
          it { should be_false }
        end

        context 'when in an instance method in #describe block' do
          let(:scopes) { [:example_group, :def] }
          it { should be_true }
        end

        context 'when in an instance method in #describe block in a module' do
          let(:scopes) { [:module, :example_group, :def] }
          it { should be_true }
        end

        context 'when in a block in #describe block' do
          let(:scopes) { [:example_group, :block] }
          it { should be_true }
        end

        context 'when in a block in #describe block in a module' do
          let(:scopes) { [:module, :example_group, :block] }
          it { should be_true }
        end

        context 'when in a class in a block in #describe block' do
          let(:scopes) { [:example_group, :block, :class] }
          it { should be_false }
        end

        context 'when in an instance method in a class in a block in #describe block' do
          let(:scopes) { [:example_group, :block, :class, :def] }
          it { should be_false }
        end

        context 'when in an instance method in a module' do
          # Instance methods of module can be used by `include SomeModule` in #describe block.
          let(:scopes) { [:module, :def] }
          it { should be_true }
        end

        context 'when in an instance method in a class' do
          let(:scopes) { [:class, :def] }
          it { should be_false }
        end

        context 'when in RSpec.configure' do
          let(:scopes) { [:rspec_configure] }
          it { should be_false }
        end

        context 'when in a block in RSpec.configure' do
          let(:scopes) { [:rspec_configure, :block] }
          it { should be_true }
        end

        context 'when in an instance method in RSpec.configure' do
          let(:scopes) { [:rspec_configure, :def] }
          it { should be_true }
        end
      end
    end
  end
end
