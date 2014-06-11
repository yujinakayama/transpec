# coding: utf-8

require 'spec_helper'
require 'transpec/cli'

module Transpec
  describe 'conversion' do
    include FileHelper
    include_context 'isolated environment'

    let(:cli) do
      DynamicAnalyzer.any_instance.stub(:silent?).and_return(true)
      cli = CLI.new
      cli.stub(:puts)
      cli
    end

    let(:spec_path) { 'spec/example_spec.rb' }

    let(:converted_source) do
      create_file(spec_path, source)
      cli.run([])
      File.read(spec_path)
    end

    describe 'one-liner expectation with have(n).items matcher' do
      let(:source) do
        <<-END
          class Team
            def players
              [:foo, :bar, :baz]
            end
          end

          describe 'example' do
            describe 'collection' do
              subject { [:foo, :bar, :baz] }

              it { should have(3).items }
            end

            describe 'owner of collection' do
              subject { Team.new }

              it { should have_at_least(3).players }
            end
          end
        END
      end

      let(:expected_source) do
        <<-END
          class Team
            def players
              [:foo, :bar, :baz]
            end
          end

          describe 'example' do
            describe 'collection' do
              subject { [:foo, :bar, :baz] }

              it 'has 3 items' do
                expect(subject.size).to eq(3)
              end
            end

            describe 'owner of collection' do
              subject { Team.new }

              it 'has at least 3 players' do
                expect(subject.players.size).to be >= 3
              end
            end
          end
        END
      end

      it 'is converted properly' do
        converted_source.should == expected_source
      end

      context 'with #its' do
        let(:source) do
          <<-END
            describe 'example' do
              subject { 'foo' }
              its(:chars) { should have(3).items }
            end
          END
        end

        let(:expected_source) do
          <<-END
            describe 'example' do
              subject { 'foo' }

              describe '#chars' do
                subject { super().chars }

                it 'has 3 items' do
                  expect(subject.size).to eq(3)
                end
              end
            end
          END
        end

        it 'is converted properly' do
          converted_source.should == expected_source
        end
      end
    end

    describe 'one-liner expectation with operator matcher' do
      context 'in RSpec 2.99.0.beta2 or later' do
        before do
          cli.project.stub(:rspec_version).and_return(RSpecVersion.new('2.99.0.beta2'))
        end

        let(:source) do
          <<-END
            describe 'example' do
              subject { 1 }
              it { should == 1 }
            end
          END
        end

        let(:expected_source) do
          <<-END
            describe 'example' do
              subject { 1 }
              it { is_expected.to eq(1) }
            end
          END
        end

        it 'is converted properly' do
          converted_source.should == expected_source
        end
      end
    end
  end
end
