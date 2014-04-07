# coding: utf-8

require 'spec_helper'
require 'transpec/cli'

module Transpec
  describe 'RSpec.configure modification' do
    include FileHelper
    include_context 'isolated environment'

    let(:cli) do
      DynamicAnalyzer.any_instance.stub(:silent?).and_return(true)
      cli = CLI.new
      cli.stub(:puts)
      cli
    end

    context 'when there are multiple RSpec.configure in the spec suite' do
      before do
        create_file('spec/spec_helper.rb', <<-END)
          RSpec.configure do |config|
          end
        END

        create_file('spec/unit/spec_helper.rb', <<-END)
          require 'spec_helper'

          RSpec.configure do |config|
          end
        END

        create_file('spec/unit/unit_spec.rb', <<-END)
          require 'unit/spec_helper'

          describe 'example' do
            it 'responds to #message' do
              Object.any_instance.stub(:message) do |arg|
              end
            end
          end
        END
      end

      it 'modifies only the one that was run first' do
        cli.project.stub(:rspec_version).and_return(RSpecVersion.new('2.99.0'))
        cli.run([])

        File.read('spec/spec_helper.rb').should == <<-END
          RSpec.configure do |config|
            config.mock_with :rspec do |mocks|
              mocks.yield_receiver_to_any_instance_implementation_blocks = true
            end
          end
        END

        File.read('spec/unit/spec_helper.rb').should == <<-END
          require 'spec_helper'

          RSpec.configure do |config|
          end
        END
      end
    end

    describe 'yield_receiver_to_any_instance_implementation_blocks' do
      let(:spec_helper_path) { 'spec/spec_helper.rb' }

      before do
        create_file(spec_helper_path, <<-END)
          RSpec.configure do |config|
          end
        END
      end

      [
        'Object.any_instance.stub(:message)',
        'Object.any_instance.should_receive(:message)',
        'allow_any_instance_of(Object).to receive(:message)',
        'expect_any_instance_of(Object).to receive(:message)'
      ].each do |syntax|
        context "when there's a #{syntax} block to convert" do
          before do
            create_file('spec/example_spec.rb', <<-END)
              describe 'example' do
                it 'responds to #message' do
                  #{syntax} do |arg|
                  end
                end
              end
            END
          end

          it 'adds yield_receiver_to_any_instance_implementation_blocks to the RSpec.configure' do
            cli.project.stub(:rspec_version).and_return(RSpecVersion.new('2.99.0'))
            cli.run([])

            File.read(spec_helper_path).should == <<-END
          RSpec.configure do |config|
            config.mock_with :rspec do |mocks|
              mocks.yield_receiver_to_any_instance_implementation_blocks = true
            end
          end
            END
          end
        end
      end

      context "when there's no any_instance blocks to convert" do
        before do
          create_file('spec/example_spec.rb', <<-END)
            describe 'example' do
              it 'responds to #foo' do
                Object.any_instance.stub(:foo) do
                end
              end
            end
          END
        end

        it 'does not modify RSpec.configure' do
          cli.project.stub(:rspec_version).and_return(RSpecVersion.new('2.99.0'))
          cli.run([])

          File.read(spec_helper_path).should == <<-END
          RSpec.configure do |config|
          end
          END
        end
      end
    end
  end
end
