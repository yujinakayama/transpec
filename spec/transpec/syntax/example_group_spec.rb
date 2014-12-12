# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/example_group'
require 'ast'
require 'active_support/core_ext/string/strip.rb'

module Transpec
  class Syntax
    describe ExampleGroup do
      include ::AST::Sexp, FileHelper
      include_context 'parsed objects'
      include_context 'syntax object', ExampleGroup, :example_group

      let(:record) { example_group.report.records.first }

      describe '#convert_to_non_monkey_patch!' do
        context 'when it is in top level scope' do
          [
            :describe,
            :shared_examples,
            :shared_context,
            :share_examples_for,
            :shared_examples_for
          ].each do |method|
            context "with expression `#{method} 'something' do ... end`" do
              let(:source) do
                <<-END
                  #{method} 'something' do
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  RSpec.#{method} 'something' do
                  end
                END
              end

              it "converts to `RSpec.#{method} 'something' do ... end`" do
                example_group.convert_to_non_monkey_patch!
                rewritten_source.should == expected_source
              end

              it "adds record `#{method} 'something' { }` -> `RSpec.#{method} 'something' { }`" do
                example_group.convert_to_non_monkey_patch!
                record.old_syntax.should == "#{method} 'something' { }"
                record.new_syntax.should == "RSpec.#{method} 'something' { }"
              end
            end
          end
        end

        context "with expression `RSpec.describe 'something' do ... end`" do
          let(:source) do
            <<-END
              RSpec.describe 'something' do
              end
            END
          end

          it 'does nothing' do
            example_group.convert_to_non_monkey_patch!
            rewritten_source.should == source
          end
        end

        context 'when the #describe is in a module' do
          let(:source) do
            <<-END
              module SomeModule
                describe 'something' do
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              module SomeModule
                RSpec.describe 'something' do
                end
              end
            END
          end

          it 'converts' do
            example_group.convert_to_non_monkey_patch!
            rewritten_source.should == expected_source
          end
        end

        shared_context 'multiple #describes' do
          before do
            ast.each_node do |node|
              example_group = described_class.new(node, runtime_data, project, source_rewriter)
              next unless example_group.conversion_target?
              example_group.convert_to_non_monkey_patch!
            end
          end
        end

        context 'when #describes are nested' do
          include_context 'multiple #describes'

          let(:source) do
            <<-END
              describe 'something' do
                describe '#some_method' do
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              RSpec.describe 'something' do
                describe '#some_method' do
                end
              end
            END
          end

          it 'converts only the outermost #describe' do
            rewritten_source.should == expected_source
          end
        end

        context 'when the #describe is in another RSpec.describe' do
          include_context 'multiple #describes'

          let(:source) do
            <<-END
              RSpec.describe 'something' do
                describe '#some_method' do
                end
              end
            END
          end

          context 'without runtime information' do
            it 'does nothing' do
              rewritten_source.should == source
            end
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            it 'does nothing' do
              rewritten_source.should == source
            end
          end
        end

        context 'when logical-inner #describe is placed outside of the outer #describe in source' do
          include_context 'multiple #describes'

          let(:source) do
            <<-END
              inner_proc = proc do
                describe 'inner' do
                end
              end

              describe 'outer' do
                instance_eval(&inner_proc)
              end
            END
          end

          context 'without runtime information' do
            let(:expected_source) do
              <<-END
              inner_proc = proc do
                RSpec.describe 'inner' do
                end
              end

              RSpec.describe 'outer' do
                instance_eval(&inner_proc)
              end
              END
            end

            it 'unfortunately converts both #describe' do
              rewritten_source.should == expected_source
            end
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            let(:expected_source) do
              <<-END
              inner_proc = proc do
                describe 'inner' do
                end
              end

              RSpec.describe 'outer' do
                instance_eval(&inner_proc)
              end
              END
            end

            it 'properly converts only the outermost #describe' do
              rewritten_source.should == expected_source
            end
          end
        end
      end

      describe '#metadata_key_nodes' do
        subject { example_group.metadata_key_nodes }

        context "with expression `describe 'something' { }`" do
          let(:source) do
            <<-END
              describe 'example' do
              end
            END
          end

          it 'returns empty array' do
            should be_empty
          end
        end

        context "with expression `describe 'something', '#some_method' { }`" do
          let(:source) do
            <<-END
              describe 'something', '#some_method' do
              end
            END
          end

          it 'returns empty array' do
            should be_empty
          end
        end

        context "with expression `describe 'something', :foo { }`" do
          let(:source) do
            <<-END
              describe 'something', :foo do
              end
            END
          end

          it 'returns [(sym :foo)]' do
            should == [s(:sym, :foo)]
          end
        end

        context "with expression `describe 'something', foo: true { }`" do
          let(:source) do
            <<-END
              describe 'something', foo: true do
              end
            END
          end

          it 'returns [(sym :foo)]' do
            should == [s(:sym, :foo)]
          end
        end

        context "with expression `describe 'something', :foo, :bar, baz: true { }`" do
          let(:source) do
            <<-END
              describe 'something', :foo, :bar, baz: true do
              end
            END
          end

          it 'returns [s(:sym, :foo), s(:sym, :bar), s(:sym, :baz)]' do
            should == [s(:sym, :foo), s(:sym, :bar), s(:sym, :baz)]
          end
        end
      end

      describe '#add_explicit_type_metadata!' do
        context 'in rspec-rails project' do
          before do
            example_group.stub(:rspec_rails?).and_return(true)
            example_group.add_explicit_type_metadata!
          end

          context 'when it is in top level scope' do
            context "and expression `describe 'something' do ... end`" do
              let(:source) do
                <<-END
                      describe 'something' do
                      end
                END
              end

              {
                'controllers' => :controller,
                'helpers'     => :helper,
                'mailers'     => :mailer,
                'models'      => :model,
                'requests'    => :request,
                'integration' => :request,
                'api'         => :request,
                'routing'     => :routing,
                'views'       => :view,
                'features'    => :feature
              }.each do |directory, type|
                context "and the file path is \"spec/#{directory}/some_spec.rb\"" do
                  let(:source_path) { "spec/#{directory}/some_spec.rb" }

                  let(:expected_source) do
                    <<-END
                      describe 'something', :type => #{type.inspect} do
                      end
                    END
                  end

                  it "adds metadata \":type => #{type.inspect}\"" do
                    rewritten_source.should == expected_source
                  end

                  it "adds record `describe 'some #{type}' { }` " \
                     "-> `describe 'some #{type}', :type => #{type.inspect} { }`" do
                    record.old_syntax.should == "describe 'some #{type}' { }"
                    record.new_syntax.should == "describe 'some #{type}', :type => #{type.inspect} { }"
                  end
                end
              end

              context 'and the file path is "spec/contollers/some_namespace/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_namespace/some_spec.rb' }

                let(:expected_source) do
                  <<-END
                      describe 'something', :type => :controller do
                      end
                  END
                end

                it 'adds metadata ":type => :controller' do
                  rewritten_source.should == expected_source
                end
              end

              context 'and the file path is "spec/unit/some_spec.rb"' do
                let(:source_path) { 'spec/unit/some_spec.rb' }

                it 'does nothing' do
                  rewritten_source.should == source
                end
              end

              context 'and the file path is "features/controllers/some_spec.rb"' do
                let(:source_path) { 'features/controllers/some_spec.rb' }

                it 'does nothing' do
                  rewritten_source.should == source
                end
              end
            end

            context "and expression `describe 'something', :foo => :bar do ... end`" do
              let(:source) do
                <<-END
                    describe 'something', :foo => :bar do
                    end
                END
              end

              context 'and the file path is "spec/controllers/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_spec.rb' }

                let(:expected_source) do
                  <<-END
                    describe 'something', :type => :controller, :foo => :bar do
                    end
                  END
                end

                it 'adds metadata ":type => :controller" to the beginning of the hash metadata' do
                  rewritten_source.should == expected_source
                end
              end
            end

            context "and expression `describe 'something', '#some_method', :foo, :bar => true do ... end`" do
              let(:source) do
                <<-END
                    describe 'something', '#some_method', :foo, :bar => true do
                    end
                END
              end

              context 'and the file path is "spec/controllers/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_spec.rb' }

                let(:expected_source) do
                  <<-END
                    describe 'something', '#some_method', :foo, :type => :controller, :bar => true do
                    end
                  END
                end

                it 'adds metadata ":type => :controller" to the beginning of the hash metadata' do
                  rewritten_source.should == expected_source
                end
              end
            end

            context "and expression `describe 'something', foo: :bar do ... end`" do
              let(:source) do
                <<-END
                    describe 'something', foo: :bar do
                    end
                END
              end

              context 'and the file path is "spec/controllers/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_spec.rb' }

                let(:expected_source) do
                  <<-END
                    describe 'something', type: :controller, foo: :bar do
                    end
                  END
                end

                it 'adds metadata "type: :controller"' do
                  rewritten_source.should == expected_source
                end
              end
            end

            context "and expression `describe 'something', :type => :foo do ... end`" do
              let(:source) do
                <<-END
                    describe 'something', :type => :foo do
                    end
                END
              end

              context 'and the file path is "spec/controllers/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_spec.rb' }

                it 'does nothing' do
                  rewritten_source.should == source
                end
              end
            end

            context "and expression `RSpec.describe 'something' do ... end`" do
              let(:source) do
                <<-END
                    RSpec.describe 'something' do
                    end
                END
              end

              context 'and the file path is "spec/controllers/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_spec.rb' }

                let(:expected_source) do
                  <<-END
                    RSpec.describe 'something', :type => :controller do
                    end
                  END
                end

                it 'adds metadata ":type => :controller"' do
                  rewritten_source.should == expected_source
                end
              end
            end

            context "and expression `shared_examples 'something' do ... end`" do
              let(:source) do
                <<-END
                    shared_examples 'something' do
                    end
                END
              end

              context 'and the file path is "spec/controllers/some_spec.rb"' do
                let(:source_path) { 'spec/controllers/some_spec.rb' }

                it 'does nothing' do
                  rewritten_source.should == source
                end
              end
            end
          end

          context 'when #describes are nested' do
            let(:source_path) { 'spec/controllers/some_spec.rb' }

            let(:source) do
              <<-END
                describe 'something' do
                  describe '#some_method' do
                  end
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'something', :type => :controller do
                  describe '#some_method' do
                  end
                end
              END
            end

            it 'adds the metadata only to the outmost #describe' do
              rewritten_source.should == expected_source
            end
          end
        end

        context 'with runtime information' do
          include_context 'dynamic analysis objects'

          let(:source_path) { 'spec/controllers/some_spec.rb' }

          before do
            example_group.add_explicit_type_metadata!
          end

          context 'when rspec-rails is loaded in the spec' do
            let(:source) do
              <<-END
                module RSpec
                  module Rails
                  end
                end

                describe 'something' do
                end
              END
            end

            let(:expected_source) do
              <<-END
                module RSpec
                  module Rails
                  end
                end

                describe 'something', :type => :controller do
                end
              END
            end

            it 'adds the metadata' do
              rewritten_source.should == expected_source
            end
          end

          context 'when rspec-rails is not loaded in the spec' do
            let(:source) do
              <<-END
                describe 'something' do
                end
              END
            end

            it 'does nothing' do
              rewritten_source.should == source
            end
          end
        end

        context 'without runtime information' do
          include_context 'isolated environment'

          let(:source_path) { 'spec/controllers/some_spec.rb' }

          let(:source) do
            <<-END
                module RSpec
                  module Rails
                  end
                end

                describe 'something' do
                end
            END
          end

          context 'when rspec-rails is specified in the Gemfile.lock' do
            before do
              create_file('Gemfile.lock', <<-END.strip_heredoc)
                GEM
                  remote: https://rubygems.org/
                  specs:
                    actionpack (4.1.8)
                      actionview (= 4.1.8)
                      activesupport (= 4.1.8)
                      rack (~> 1.5.2)
                      rack-test (~> 0.6.2)
                    actionview (4.1.8)
                      activesupport (= 4.1.8)
                      builder (~> 3.1)
                      erubis (~> 2.7.0)
                    activemodel (4.1.8)
                      activesupport (= 4.1.8)
                      builder (~> 3.1)
                    activesupport (4.1.8)
                      i18n (~> 0.6, >= 0.6.9)
                      json (~> 1.7, >= 1.7.7)
                      minitest (~> 5.1)
                      thread_safe (~> 0.1)
                      tzinfo (~> 1.1)
                    builder (3.2.2)
                    diff-lcs (1.2.5)
                    erubis (2.7.0)
                    i18n (0.6.11)
                    json (1.8.1)
                    minitest (5.4.3)
                    rack (1.5.2)
                    rack-test (0.6.2)
                      rack (>= 1.0)
                    railties (4.1.8)
                      actionpack (= 4.1.8)
                      activesupport (= 4.1.8)
                      rake (>= 0.8.7)
                      thor (>= 0.18.1, < 2.0)
                    rake (10.4.2)
                    rspec-core (2.14.8)
                    rspec-expectations (2.14.5)
                      diff-lcs (>= 1.1.3, < 2.0)
                    rspec-mocks (2.14.6)
                    rspec-rails (2.14.2)
                      actionpack (>= 3.0)
                      activemodel (>= 3.0)
                      activesupport (>= 3.0)
                      railties (>= 3.0)
                      rspec-core (~> 2.14.0)
                      rspec-expectations (~> 2.14.0)
                      rspec-mocks (~> 2.14.0)
                    thor (0.19.1)
                    thread_safe (0.3.4)
                    tzinfo (1.2.2)
                      thread_safe (~> 0.1)

                PLATFORMS
                  ruby

                DEPENDENCIES
                  rspec-rails (~> 2.14.0)
              END
            end

            let(:expected_source) do
              <<-END
                module RSpec
                  module Rails
                  end
                end

                describe 'something', :type => :controller do
                end
              END
            end

            it 'adds the metadata' do
              example_group.add_explicit_type_metadata!
              rewritten_source.should == expected_source
            end
          end

          context 'when rspec-rails is not specified in the Gemfile.lock' do
            before do
              create_file('Gemfile.lock', <<-END.strip_heredoc)
                GEM
                  remote: https://rubygems.org/
                  specs:
                    diff-lcs (1.2.5)
                    rspec (2.14.1)
                      rspec-core (~> 2.14.0)
                      rspec-expectations (~> 2.14.0)
                      rspec-mocks (~> 2.14.0)
                    rspec-core (2.14.8)
                    rspec-expectations (2.14.5)
                      diff-lcs (>= 1.1.3, < 2.0)
                    rspec-mocks (2.14.6)

                PLATFORMS
                  ruby

                DEPENDENCIES
                  rspec (~> 2.14.0)
              END
            end

            it 'does nothing' do
              example_group.add_explicit_type_metadata!
              rewritten_source.should == source
            end
          end

          context 'when there is no Gemfile.lock' do
            it 'does nothing' do
              example_group.add_explicit_type_metadata!
              rewritten_source.should == source
            end
          end
        end
      end
    end
  end
end
