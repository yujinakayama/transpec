# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/its'

module Transpec
  class Syntax
    describe Its do
      include_context 'parsed objects'
      include_context 'syntax object', Its, :its_object

      let(:record) { its_object.report.records.last }

      describe '#conversion_target?' do
        let(:its_node) do
          ast.each_node(:send).find do |send_node|
            method_name = send_node.children[1]
            method_name == :its
          end
        end

        let(:its_object) do
          Its.new(its_node, source_rewriter, runtime_data)
        end

        subject { its_object.conversion_target? }

        context 'when rspec-its is loaded in the spec' do
          let(:source) do
            <<-END
              module RSpec
                module Its
                end
              end

              describe 'example' do
                subject { ['foo'] }

                its(:size) { should == 1 }
              end
            END
          end

          context 'without runtime information' do
            it { should be_true }
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'
            it { should be_false }
          end
        end
      end

      describe '#convert_to_describe_subject_it!' do
        before do
          its_object.convert_to_describe_subject_it!
        end

        context 'with expression `its(:size) { ... }`' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { ['foo'] }

                its(:size) { should == 1 }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { ['foo'] }

                describe '#size' do
                  subject { super().size }
                  it { should == 1 }
                end
              end
            END
          end

          it "converts to `describe '#size' do subject { super().size }; it { ... } end` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `its(:attr) { }` -> `describe '#attr' do subject { super().attr }; it { } end`" do
            record.old_syntax.should == 'its(:attr) { }'
            record.new_syntax.should == "describe '#attr' do subject { super().attr }; it { } end"
          end

          context 'and there are consecutive blanks between the #its and the block' do
            let(:source) do
              <<-END
                describe 'example' do
                  subject { ['foo'] }
                  its(:size)   { should == 1 }
                end
              END
            end

            let(:expected_source) do
              <<-END
                describe 'example' do
                  subject { ['foo'] }

                  describe '#size' do
                    subject { super().size }
                    it { should == 1 }
                  end
                end
              END
            end

            it 'removes the redundant blanks' do
              rewritten_source.should == expected_source
            end
          end

          context 'and there is no blank line before #its' do
            context 'and the indentation level of the previous line is same as the target line' do
              let(:source) do
                <<-END
                  describe 'example' do
                    subject { ['foo'] }
                    its(:size) { should == 1 }
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  describe 'example' do
                    subject { ['foo'] }

                    describe '#size' do
                      subject { super().size }
                      it { should == 1 }
                    end
                  end
                END
              end

              it 'inserts a blank line before #its' do
                rewritten_source.should == expected_source
              end
            end

            context 'and the indentation level of the previous line is lower than the target line' do
              let(:source) do
                <<-END
                  describe 'example' do
                    subject { ['foo'] }

                    context 'in some case' do
                      its(:size) { should == 1 }
                    end
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  describe 'example' do
                    subject { ['foo'] }

                    context 'in some case' do
                      describe '#size' do
                        subject { super().size }
                        it { should == 1 }
                      end
                    end
                  end
                END
              end

              it 'does not insert blank line before #its' do
                rewritten_source.should == expected_source
              end
            end
          end
        end

        context "with expression `its('size') { ... }`" do
          let(:source) do
            <<-END
              describe 'example' do
                subject { ['foo'] }

                its('size') { should == 1 }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { ['foo'] }

                describe '#size' do
                  subject { super().size }
                  it { should == 1 }
                end
              end
            END
          end

          it "converts to `describe '#size' do subject { super().size }; it { ... } end` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `its(:attr) { }` -> `describe '#attr' do subject { super().attr }; it { } end`" do
            record.old_syntax.should == 'its(:attr) { }'
            record.new_syntax.should == "describe '#attr' do subject { super().attr }; it { } end"
          end
        end

        context "with expression `its('size.odd?') { ... }`" do
          let(:source) do
            <<-END
              describe 'example' do
                subject { ['foo'] }

                its('size.odd?') { should be_true }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { ['foo'] }

                describe '#size' do
                  subject { super().size }
                  describe '#odd?' do
                    subject { super().odd? }
                    it { should be_true }
                  end
                end
              end
            END
          end

          it 'converts to nested #describe' do
            rewritten_source.should == expected_source
          end

          it "adds record `its(:attr) { }` -> `describe '#attr' do subject { super().attr }; it { } end`" do
            record.old_syntax.should == 'its(:attr) { }'
            record.new_syntax.should == "describe '#attr' do subject { super().attr }; it { } end"
          end
        end

        context 'with expression `its([:foo]) { ... }`' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { { foo: 'bar' } }

                its([:foo]) { should == 'bar' }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { { foo: 'bar' } }

                describe '[:foo]' do
                  subject { super()[:foo] }
                  it { should == 'bar' }
                end
              end
            END
          end

          it "converts to `describe '[:foo]' do subject { super()[:foo] }; it { ... } end` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `its([:key]) { }` -> `describe '[:key]' do subject { super()[:key] }; it { } end`" do
            record.old_syntax.should == 'its([:key]) { }'
            record.new_syntax.should == "describe '[:key]' do subject { super()[:key] }; it { } end"
          end
        end

        context "with expression `its(['foo']) { ... }`" do
          let(:source) do
            <<-END
              describe 'example' do
                subject { { 'foo' => 'bar' } }

                its(['foo']) { should == 'bar' }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { { 'foo' => 'bar' } }

                describe "['foo']" do
                  subject { super()['foo'] }
                  it { should == 'bar' }
                end
              end
            END
          end

          it "converts to `describe \"['foo']\" do subject { super()['foo'] }; it { ... } end` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `its([:key]) { }` -> `describe '[:key]' do subject { super()[:key] }; it { } end`" do
            record.old_syntax.should == 'its([:key]) { }'
            record.new_syntax.should == "describe '[:key]' do subject { super()[:key] }; it { } end"
          end
        end

        context 'with expression `its([3, 2]) { ... }`' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { %w(a b c d r f g) }

                its([3, 2]) { should == %w(d r) }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { %w(a b c d r f g) }

                describe '[3, 2]' do
                  subject { super()[3, 2] }
                  it { should == %w(d r) }
                end
              end
            END
          end

          it "converts to `describe '[3, 2]' do subject { super()[3, 2] }; it { ... } end` form" do
            rewritten_source.should == expected_source
          end

          it "adds record `its([:key]) { }` -> `describe '[:key]' do subject { super()[:key] }; it { } end`" do
            record.old_syntax.should == 'its([:key]) { }'
            record.new_syntax.should == "describe '[:key]' do subject { super()[:key] }; it { } end"
          end
        end

        context 'with expression `its(attribute) { ... }`' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { 'foo' }

                [
                  [:size,       3],
                  [:upcase, 'FOO']
                ].each do |attribute, expected_value|
                  its(attribute) { should == expected_value }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { 'foo' }

                [
                  [:size,       3],
                  [:upcase, 'FOO']
                ].each do |attribute, expected_value|
                  describe attribute do
                    subject { super().send(attribute) }
                    it { should == expected_value }
                  end
                end
              end
            END
          end

          it 'converts to `describe attribute do subject { super().send(attribute) }; it { ... } end` form' do
            rewritten_source.should == expected_source
          end

          it "adds record `its(:attr) { }` -> `describe '#attr' do subject { super().attr }; it { } end`" do
            record.old_syntax.should == 'its(:attr) { }'
            record.new_syntax.should == "describe '#attr' do subject { super().attr }; it { } end"
          end
        end

        context 'with expression `its([1, length]) { ... }`' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { 'foobar' }

                [
                  [2, 'oo'],
                  [3, 'oob']
                ].each do |length, expected_value|
                  its([1, length]) { should == expected_value }
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                subject { 'foobar' }

                [
                  [2, 'oo'],
                  [3, 'oob']
                ].each do |length, expected_value|
                  describe [1, length] do
                    subject { super()[1, length] }
                    it { should == expected_value }
                  end
                end
              end
            END
          end

          it 'converts to `describe [1, length] do subject { super()[1, length] }; it { ... } end` form' do
            rewritten_source.should == expected_source
          end

          it "adds record `its([:key]) { }` -> `describe '[:key]' do subject { super()[:key] }; it { } end`" do
            record.old_syntax.should == 'its([:key]) { }'
            record.new_syntax.should == "describe '[:key]' do subject { super()[:key] }; it { } end"
          end
        end
      end
    end
  end
end
