# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/oneliner_should'

module Transpec
  class Syntax
    describe OnelinerShould do
      include_context 'parsed objects'
      include_context 'syntax object', OnelinerShould, :should_object

      let(:record) { should_object.report.records.first }

      describe '#conversion_target?' do
        let(:target_node) do
          ast.each_node(:send).find do |send_node|
            method_name = send_node.children[1]
            method_name == :should
          end
        end

        let(:should_object) do
          OnelinerShould.new(target_node, source_rewriter, runtime_data)
        end

        subject { should_object.conversion_target? }

        context 'when one-liner #should node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { 1 }
                it { should == 1 }
              end
            END
          end

          it { should be_true }

          context 'with runtime information' do
            include_context 'dynamic analysis objects'
            it { should be_true }
          end
        end

        context 'when monkey-patched #should node is passed' do
          let(:source) do
            <<-END
              describe 'example' do
                subject { 1 }
                it 'is 1' do
                  subject.should == 1
                end
              end
            END
          end

          it { should be_false }
        end
      end

      describe '#matcher_node' do
        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'returns its parent node' do
            should_object.parent_node.children[1].should == :==
            should_object.matcher_node.should == should_object.parent_node
          end
        end

        context 'when it is taking non-operator matcher without argument' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be_empty }
              end
            END
          end

          it 'returns its argument node' do
            should_object.arg_node.children[1].should == :be_empty
            should_object.matcher_node.should == should_object.arg_node
          end
        end

        context 'when it is taking non-operator matcher with argument' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should eq(1) }
              end
            END
          end

          it 'returns its argument node' do
            should_object.arg_node.children[1].should == :eq
            should_object.matcher_node.should == should_object.arg_node
          end
        end
      end

      describe '#operator_matcher' do
        subject { should_object.operator_matcher }

        let(:source) do
          <<-END
            describe 'example' do
              it { should == 1 }
            end
          END
        end

        it 'returns an instance of Operator' do
          should be_an(Operator)
        end
      end

      describe '#have_matcher' do
        subject { should_object.have_matcher }

        let(:source) do
          <<-END
            describe 'example' do
              it { should have(2).items }
            end
          END
        end

        it 'returns an instance of Have' do
          should be_an(Have)
        end
      end

      describe '#expectize!' do
        context 'with expression `it { should be true }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be true }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it { is_expected.to be true }
              end
            END
          end

          it 'converts to `it { is_expected.to be true }` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should ... }` -> `it { is_expected.to ... }`' do
            should_object.expectize!
            record.old_syntax.should == 'it { should ... }'
            record.new_syntax.should == 'it { is_expected.to ... }'
          end
        end

        context 'with expression `it { should() == 1 }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should() == 1 }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it { is_expected.to == 1 }
              end
            END
          end

          it 'converts to `it { is_expected.to == 1 }` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end
      end

      describe '#convert_have_items_to_standard_should! and Have#convert_to_standard_expectation!' do
        before do
          should_object.convert_have_items_to_standard_should!
          should_object.have_matcher.convert_to_standard_expectation!
        end

        context 'with expression `it { should have(2).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should have(2).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  subject.size.should == 2
                end
              end
            END
          end

          it "converts to `it 'has 2 items' do subject.size.should == 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.old_syntax.should == 'it { should have(n).items }'
            record.new_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'with expression `it { should_not have(2).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should_not have(2).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not have 2 items' do
                  subject.size.should_not == 2
                end
              end
            END
          end

          it "converts to `it 'does not have 2 items' do subject.size.should_not == 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should_not have(n).items }`' \
             ' -> `it \'does not have n items\' do subject.size.should_not == n end`' do
            record.old_syntax.should == 'it { should_not have(n).items }'
            record.new_syntax.should == "it 'does not have n items' do subject.size.should_not == n end"
          end
        end

        context 'with expression `it { should have(1).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should have(1).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 1 item' do
                  subject.size.should == 1
                end
              end
            END
          end

          it "converts to `it 'has 1 item' do subject.size.should == 1 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.old_syntax.should == 'it { should have(n).items }'
            record.new_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'with expression `it { should have(0).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should have(0).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has no items' do
                  subject.size.should == 0
                end
              end
            END
          end

          it "converts to `it 'has no items' do subject.size.should == 0 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.old_syntax.should == 'it { should have(n).items }'
            record.new_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'with expression `it { should have(variable).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should have(number_of).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has number_of items' do
                  subject.size.should == number_of
                end
              end
            END
          end

          it "converts to `it 'has variable items' do subject.size.should == variable end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.old_syntax.should == 'it { should have(n).items }'
            record.new_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'with expression `it { should_not have(0).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should_not have(0).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not have 0 items' do
                  subject.size.should_not == 0
                end
              end
            END
          end

          it "converts to `it 'does not have 0 items' do subject.size.should_not == 0 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should_not have(n).items }`' \
             ' -> `it \'does not have n items\' do subject.size.should_not == n end`' do
            record.old_syntax.should == 'it { should_not have(n).items }'
            record.new_syntax.should == "it 'does not have n items' do subject.size.should_not == n end"
          end
        end

        context 'with expression multiline `it { should have(2).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it {
                  should have(2).items
                }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' {
                  subject.size.should == 2
                }
              end
            END
          end

          it "converts to `it 'has 2 items' { subject.size.should == 2 }` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.old_syntax.should == 'it { should have(n).items }'
            record.new_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context "with expression `it 'has 2 items' do should have(2).items end`" do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  should have(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  subject.size.should == 2
                end
              end
            END
          end

          it "converts to `it 'has 2 items' do subject.size.should == 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it \'...\' { should have(n).items }` -> `it \'...\' do subject.size.should == n end`' do
            record.old_syntax.should == "it '...' do should have(n).items end"
            record.new_syntax.should == "it '...' do subject.size.should == n end"
          end
        end

        context 'with expression `it { should have_at_least(2).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should have_at_least(2).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has at least 2 items' do
                  subject.size.should >= 2
                end
              end
            END
          end

          it "converts to `it 'has at least 2 items' do subject.size.should >= 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should have_at_least(n).items }` ' \
             '-> `it \'has at least n items\' do subject.size.should >= n end`' do
            record.old_syntax.should == 'it { should have_at_least(n).items }'
            record.new_syntax.should == "it 'has at least n items' do subject.size.should >= n end"
          end
        end

        context 'with expression `it { should have(2).words }`' do
          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            context 'when the subject responds to #words and #words responds to #size' do
              let(:source) do
                <<-END
                  class String
                    def words
                      split(' ')
                    end
                  end

                  describe 'a string' do
                    it { should have(2).words }
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  class String
                    def words
                      split(' ')
                    end
                  end

                  describe 'a string' do
                    it 'has 2 words' do
                      subject.words.size.should == 2
                    end
                  end
                END
              end

              it "converts to `it 'has 2 words' do subject.words.size.should == 2 end` form" do
                rewritten_source.should == expected_source
              end

              it 'adds record `it { should have(n).words }` ' \
                 '-> `it \'has n words\' do subject.words.size.should == n end`' do
                record.old_syntax.should == 'it { should have(n).words }'
                record.new_syntax.should == "it 'has n words' do subject.words.size.should == n end"
              end
            end
          end
        end
      end

      describe '#convert_have_items_to_standard_expect! and Have#convert_to_standard_expectation!' do
        before do
          should_object.convert_have_items_to_standard_expect!
          should_object.have_matcher.convert_to_standard_expectation!
        end

        context 'with expression `it { should have(2).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should have(2).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(subject.size).to eq(2)
                end
              end
            END
          end

          it "converts to `it 'has 2 items' do expect(subject.size).to eq(2) end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' \
             '`it { should have(n).items }` -> `it \'has n items\' do expect(subject.size).to eq(n) end`' do
            record.old_syntax.should == 'it { should have(n).items }'
            record.new_syntax.should == "it 'has n items' do expect(subject.size).to eq(n) end"
          end
        end

        context 'with expression `it { should_not have(2).items }`' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should_not have(2).items }
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'does not have 2 items' do
                  expect(subject.size).not_to eq(2)
                end
              end
            END
          end

          it "converts to `it 'does not have 2 items' do expect(subject.size).not_to eq(2) end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should_not have(n).items }`' \
             ' -> `it \'does not have n items\' do expect(subject.size).not_to eq(n) end`' do
            record.old_syntax.should == 'it { should_not have(n).items }'
            record.new_syntax.should == "it 'does not have n items' do expect(subject.size).not_to eq(n) end"
          end
        end
      end
    end
  end
end
