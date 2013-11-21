# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/oneliner_should'

module Transpec
  class Syntax
    describe OnelinerShould do
      include_context 'parsed objects'
      include_context 'syntax object', OnelinerShould, :should_object

      let(:record) { should_object.report.records.first }

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

        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'returns an instance of OperatorMatcher' do
            should be_an(OperatorMatcher)
          end
        end

        context 'when it is taking non-operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be_empty }
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end
      end

      describe '#have_matcher' do
        subject { should_object.have_matcher }

        context 'when it is taking #have matcher' do
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

        context 'when it is taking operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end

        context 'when it is taking any other non-operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should be_empty }
              end
            END
          end

          it 'returns nil' do
            should be_nil
          end
        end
      end

      describe '#expectize!' do
        context 'when it has an operator matcher' do
          let(:source) do
            <<-END
              describe 'example' do
                it { should == 1 }
              end
            END
          end

          it 'invokes OperatorMatcher#convert_operator!' do
            should_object.operator_matcher.should_receive(:convert_operator!)
            should_object.expectize!
          end
        end

        context 'when it is `it { should be true }` form' do
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

          it 'converts into `it { is_expected.to be true }` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should ... }` -> `it { is_expected.to ... }`' do
            should_object.expectize!
            record.original_syntax.should  == 'it { should ... }'
            record.converted_syntax.should == 'it { is_expected.to ... }'
          end
        end

        context 'when it is `it { should() == 1 }` form' do
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
                it { is_expected.to eq(1) }
              end
            END
          end

          it 'converts into `it { is_expected.to eq(1) }` form' do
            should_object.expectize!
            rewritten_source.should == expected_source
          end
        end
      end

      shared_examples 'does not convert if project requires have(n).items matcher' do
        context 'when rspec-rails is loaded in the spec' do
          include_context 'dynamic analysis objects'

          let(:source) do
            <<-END
              module RSpec
                module Rails
                end
              end

              describe [:foo, :bar] do
                it { should have(2).items }
              end
            END
          end

          it 'does nothing' do
            rewritten_source.should == source
          end
        end

        context 'when rspec-collection_matchers is loaded in the spec' do
          include_context 'dynamic analysis objects'

          let(:source) do
            <<-END
              module RSpec
                module CollectionMatchers
                end
              end

              describe [:foo, :bar] do
                it { should have(2).items }
              end
            END
          end

          let(:have_object) { should_object.have_matcher }

          it 'does nothing' do
            rewritten_source.should == source
          end
        end
      end

      describe '#convert_have_items_to_standard_should!' do
        before do
          should_object.convert_have_items_to_standard_should!
        end

        include_examples 'does not convert if project requires have(n).items matcher'

        context 'when it is `it { should have(2).items }` form' do
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

          it "converts into `it 'has 2 items' do subject.size.should == 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.original_syntax.should  == 'it { should have(n).items }'
            record.converted_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'when it is `it { should_not have(2).items }` form' do
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

          it "converts into `it 'does not have 2 items' do subject.size.should_not == 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should_not have(n).items }`' +
             ' -> `it \'does not have n items\' do subject.size.should_not == n end`' do
            record.original_syntax.should  == 'it { should_not have(n).items }'
            record.converted_syntax.should == "it 'does not have n items' do subject.size.should_not == n end"
          end
        end

        context 'when it is `it { should have(1).items }` form' do
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

          it "converts into `it 'has 1 item' do subject.size.should == 1 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.original_syntax.should  == 'it { should have(n).items }'
            record.converted_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'when it is `it { should have(0).items }` form' do
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

          it "converts into `it 'has no items' do subject.size.should == 0 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.original_syntax.should  == 'it { should have(n).items }'
            record.converted_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'when it is `it { should have(variable).items }` form' do
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

          it "converts into `it 'has variable items' do subject.size.should == variable end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.original_syntax.should  == 'it { should have(n).items }'
            record.converted_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context 'when it is `it { should_not have(0).items }` form' do
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

          it "converts into `it 'does not have 0 items' do subject.size.should_not == 0 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should_not have(n).items }`' +
             ' -> `it \'does not have n items\' do subject.size.should_not == n end`' do
            record.original_syntax.should  == 'it { should_not have(n).items }'
            record.converted_syntax.should == "it 'does not have n items' do subject.size.should_not == n end"
          end
        end

        context 'when it is multiline `it { should have(2).items }` form' do
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

          it "converts into `it 'has 2 items' { subject.size.should == 2 }` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it { should have(n).items }` -> `it \'has n items\' do subject.size.should == n end`' do
            record.original_syntax.should  == 'it { should have(n).items }'
            record.converted_syntax.should == "it 'has n items' do subject.size.should == n end"
          end
        end

        context "when it is `it 'has 2 items' do should have(2).items end` form" do
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

          it "converts into `it 'has 2 items' do subject.size.should == 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it \'...\' { should have(n).items }` -> `it \'...\' do subject.size.should == n end`' do
            record.original_syntax.should  == "it '...' do should have(n).items end"
            record.converted_syntax.should == "it '...' do subject.size.should == n end"
          end
        end

        context 'when it is `it { should have_at_least(2).items }` form' do
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

          it "converts into `it 'has at least 2 items' do subject.size.should >= 2 end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should have_at_least(n).items }` ' +
             '-> `it \'has at least n items\' do subject.size.should >= n end`' do
            record.original_syntax.should  == 'it { should have_at_least(n).items }'
            record.converted_syntax.should == "it 'has at least n items' do subject.size.should >= n end"
          end
        end

        context 'when it is `it { should have(2).words }` form' do
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

              it "converts into `it 'has 2 words' do subject.words.size.should == 2 end` form" do
                rewritten_source.should == expected_source
              end

              it 'adds record `it { should have(n).words }` ' +
                 '-> `it \'has n words\' do subject.words.size.should == n end`' do
                record.original_syntax.should  == 'it { should have(n).words }'
                record.converted_syntax.should == "it 'has n words' do subject.words.size.should == n end"
              end
            end
          end
        end
      end

      describe '#convert_have_items_to_standard_expect!' do
        before do
          should_object.convert_have_items_to_standard_expect!
        end

        include_examples 'does not convert if project requires have(n).items matcher'

        context 'when it is `it { should have(2).items }` form' do
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

          it "converts into `it 'has 2 items' do expect(subject.size).to eq(2) end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record ' +
             '`it { should have(n).items }` -> `it \'has n items\' do expect(subject.size).to eq(n) end`' do
            record.original_syntax.should  == 'it { should have(n).items }'
            record.converted_syntax.should == "it 'has n items' do expect(subject.size).to eq(n) end"
          end
        end

        context 'when it is `it { should_not have(2).items }` form' do
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

          it "converts into `it 'does not have 2 items' do expect(subject.size).not_to eq(2) end` form" do
            rewritten_source.should == expected_source
          end

          it 'adds record `it { should_not have(n).items }`' +
             ' -> `it \'does not have n items\' do expect(subject.size).not_to eq(n) end`' do
            record.original_syntax.should  == 'it { should_not have(n).items }'
            record.converted_syntax.should == "it 'does not have n items' do expect(subject.size).not_to eq(n) end"
          end
        end
      end
    end
  end
end
