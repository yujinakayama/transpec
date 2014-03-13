# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/example'
require 'ast'

module Transpec
  class Syntax
    describe Example do
      include ::AST::Sexp
      include_context 'parsed objects'
      include_context 'syntax object', Example, :example_object

      let(:record) { example_object.report.records.last }

      describe '.conversion_target_node?' do
        subject { Example.conversion_target_node?(pending_node, runtime_data) }

        let(:pending_node) do
          ast.each_descendent_node do |node|
            next unless node.send_type?
            method_name = node.children[1]
            return node if method_name == :pending
          end
          fail 'No #pending node is found!'
        end

        context 'when #pending example node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                pending 'will be skipped' do
                end
              end
            END
          end

          context 'without runtime information' do
            it { should be_true }
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'
            it { should be_true }
          end
        end

        context 'when #pending specification node inside of an example is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped' do
                  pending
                end
              end
            END
          end

          context 'without runtime information' do
            it { should be_false }
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'
            it { should be_false }
          end
        end
      end

      describe '#metadata_key_nodes' do
        subject { example_object.metadata_key_nodes }

        context 'with expression `it { }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { do_something }
              end
            END
          end

          it 'returns empty array' do
            should be_empty
          end
        end

        context "with expression `it 'description' { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is an example' do
                  do_something
                end
              end
            END
          end

          it 'returns empty array' do
            should be_empty
          end
        end

        context "with expression `it 'description', :foo { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is an example', :foo do
                  do_something
                end
              end
            END
          end

          it 'returns [(sym :foo)]' do
            should == [s(:sym, :foo)]
          end
        end

        context "with expression `it 'description', foo: true { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is an example', foo: true do
                  do_something
                end
              end
            END
          end

          it 'returns [(sym :foo)]' do
            should == [s(:sym, :foo)]
          end
        end

        context "with expression `it 'description', :foo, :bar, baz: true { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is an example', :foo, :bar, baz: true do
                  do_something
                end
              end
            END
          end

          it 'returns [s(:sym, :foo), s(:sym, :bar), s(:sym, :baz)]' do
            should == [s(:sym, :foo), s(:sym, :bar), s(:sym, :baz)]
          end
        end
      end

      describe '#convert_pending_to_skip!' do
        before do
          example_object.convert_pending_to_skip!
        end

        context "with expression `pending 'is an example' { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                pending 'will be skipped' do
                  do_something
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                skip 'will be skipped' do
                  do_something
                end
              end
            END
          end

          it "converts to `skip 'is an example' { }` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `pending 'is an example' { }` -> `skip 'is an example' { }`" do
            record.original_syntax.should  == "pending 'is an example' { }"
            record.converted_syntax.should == "skip 'is an example' { }"
          end
        end

        context "with expression `it 'is an example' { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'is normal example' do
                  do_something
                end
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context "with expression `it 'is an example', :pending { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped', :pending do
                  do_something
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'will be skipped', :skip do
                  do_something
                end
              end
            END
          end

          it "converts to `it 'is an example', :skip { }` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `it 'is an example', :pending { }` -> `it 'is an example', :skip { }`" do
            record.original_syntax.should  == "it 'is an example', :pending { }"
            record.converted_syntax.should == "it 'is an example', :skip { }"
          end
        end

        context "with expression `it 'description', :pending => true { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped', :pending => true do
                  do_something
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'will be skipped', :skip => true do
                  do_something
                end
              end
            END
          end

          it "converts to `it 'description', :skip => true { }` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `it 'is an example', :pending => value { }` -> `it 'is an example', :skip => value { }`" do
            record.original_syntax.should  == "it 'is an example', :pending => value { }"
            record.converted_syntax.should == "it 'is an example', :skip => value { }"
          end
        end

        context "with expression `it 'description', pending: true { }`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'will be skipped', pending: true do
                  do_something
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'will be skipped', skip: true do
                  do_something
                end
              end
            END
          end

          it "converts to `it 'description', skip: true { }` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `it 'is an example', :pending => value { }` -> `it 'is an example', :skip => value { }`" do
            record.original_syntax.should  == "it 'is an example', :pending => value { }"
            record.converted_syntax.should == "it 'is an example', :skip => value { }"
          end
        end
      end
    end
  end
end
