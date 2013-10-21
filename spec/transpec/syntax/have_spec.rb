# coding: utf-8

require 'spec_helper'
require 'transpec/syntax/have'

module Transpec
  class Syntax
    describe Have do
      include ::AST::Sexp
      include_context 'parsed objects'
      include_context 'should object'
      include_context 'expect object'

      describe '#have_node' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'has 2 items' do
                subject.should have(2).items
              end
            end
          END
        end

        let(:have_object) { should_object.have_matcher }

        it 'returns #have node' do
          method_name = have_object.have_node.children[1]
          method_name.should == :have
        end
      end

      describe '#size_node' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'has 2 items' do
                subject.should have(2).items
              end
            end
          END
        end

        let(:have_object) { should_object.have_matcher }

        it 'returns node of collection size' do
          have_object.size_node.should == s(:int, 2)
        end
      end

      describe '#items_node' do
        let(:source) do
          <<-END
            describe 'example' do
              it 'has 2 items' do
                subject.should have(2).items
              end
            end
          END
        end

        let(:have_object) { should_object.have_matcher }

        it 'returns #items node' do
          method_name = have_object.items_node.children[1]
          method_name.should == :items
        end
      end

      describe '#convert_to_standard_expectation!' do
        let(:record) { have_object.report.records.last }

        context 'when it is `collection.should have(2).items` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  collection.should have(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  collection.size.should == 2
                end
              end
            END
          end

          let(:have_object) { should_object.have_matcher }

          it 'converts into `collection.size.should == 2` form' do
            have_object.convert_to_standard_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`collection.should have(n).items` -> `collection.size.should == n`"' do
            have_object.convert_to_standard_expectation!
            record.original_syntax.should  == 'collection.should have(n).items'
            record.converted_syntax.should == 'collection.size.should == n'
          end

          context 'and Should#expectize! is invoked before it' do
            let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection.size).to eq(2)
                end
              end
            END
            end

            before do
              should_object.expectize!
              should_object.have_matcher.convert_to_standard_expectation!
            end

            it 'converts into `expect(collection.size).to eq(2)` form' do
              rewritten_source.should == expected_source
            end

            it 'adds record "`collection.should have(n).items` -> `expect(collection.size).to eq(n)`"' do
              record.original_syntax.should  == 'collection.should have(n).items'
              record.converted_syntax.should == 'expect(collection.size).to eq(n)'
            end
          end
        end

        context 'when it is `collection.should have_at_least(2).items` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  collection.should have_at_least(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  collection.size.should >= 2
                end
              end
            END
          end

          let(:have_object) { should_object.have_matcher }

          it 'converts into `collection.size.should >= 2` form' do
            have_object.convert_to_standard_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`collection.should have_at_least(n).items` -> `collection.size.should >= n`"' do
            have_object.convert_to_standard_expectation!
            record.original_syntax.should  == 'collection.should have_at_least(n).items'
            record.converted_syntax.should == 'collection.size.should >= n'
          end
        end

        context 'when it is `collection.should have_at_most(2).items` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  collection.should have_at_most(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  collection.size.should <= 2
                end
              end
            END
          end

          let(:have_object) { should_object.have_matcher }

          it 'converts into `collection.size.should >= 2` form' do
            have_object.convert_to_standard_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`collection.should have_at_most(n).items` -> `collection.size.should <= n`"' do
            have_object.convert_to_standard_expectation!
            record.original_syntax.should  == 'collection.should have_at_most(n).items'
            record.converted_syntax.should == 'collection.size.should <= n'
          end
        end

        context 'when it is `expect(collection).to have(2).items` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection).to have(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection.size).to eq(2)
                end
              end
            END
          end

          let(:have_object) { expect_object.have_matcher }

          it 'converts into `expect(collection.size).to eq(2)` form' do
            have_object.convert_to_standard_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`expect(collection).to have(n).items` -> `expect(collection.size).to eq(n)`"' do
            have_object.convert_to_standard_expectation!
            record.original_syntax.should  == 'expect(collection).to have(n).items'
            record.converted_syntax.should == 'expect(collection.size).to eq(n)'
          end

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            context 'when the collection responds to only #count' do
              let(:source) do
                <<-END
                  class SomeCollection
                    def count
                      2
                    end
                  end

                  describe SomeCollection do
                    it 'has 2 items' do
                      expect(subject).to have(2).items
                    end
                  end
                END
              end

              let(:expected_source) do
                <<-END
                  class SomeCollection
                    def count
                      2
                    end
                  end

                  describe SomeCollection do
                    it 'has 2 items' do
                      expect(subject.count).to eq(2)
                    end
                  end
                END
              end

              it 'converts into `expect(collection.count).to eq(2)` form' do
                have_object.convert_to_standard_expectation!
                rewritten_source.should == expected_source
              end

              it 'adds record "`expect(collection).to have(n).items` -> `expect(collection.size).to eq(n)`"' do
                have_object.convert_to_standard_expectation!
                record.original_syntax.should  == 'expect(collection).to have(n).items'
                record.converted_syntax.should == 'expect(collection.size).to eq(n)'
              end
            end
          end
        end

        context 'when it is `expect(collection).to have_at_least(2).items` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection).to have_at_least(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection.size).to be >= 2
                end
              end
            END
          end

          let(:have_object) { expect_object.have_matcher }

          it 'converts into `expect(collection.size).to be >= 2` form' do
            have_object.convert_to_standard_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`expect(collection).to have_at_least(n).items` -> `expect(collection.size).to be >= n`"' do
            have_object.convert_to_standard_expectation!
            record.original_syntax.should  == 'expect(collection).to have_at_least(n).items'
            record.converted_syntax.should == 'expect(collection.size).to be >= n'
          end
        end

        context 'when it is `expect(collection).to have_at_most(2).items` form' do
          let(:source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection).to have_at_most(2).items
                end
              end
            END
          end

          let(:expected_source) do
            <<-END
              describe 'example' do
                it 'has 2 items' do
                  expect(collection.size).to be <= 2
                end
              end
            END
          end

          let(:have_object) { expect_object.have_matcher }

          it 'converts into `expect(collection.size).to be <= 2` form' do
            have_object.convert_to_standard_expectation!
            rewritten_source.should == expected_source
          end

          it 'adds record "`expect(collection).to have_at_most(n).items` -> `expect(collection.size).to be <= n`"' do
            have_object.convert_to_standard_expectation!
            record.original_syntax.should  == 'expect(collection).to have_at_most(n).items'
            record.converted_syntax.should == 'expect(collection.size).to be <= n'
          end
        end

        context 'when it is `expect(subject).to have(2).words` form' do
          let(:have_object) { expect_object.have_matcher }

          context 'with runtime information' do
            include_context 'dynamic analysis objects'

            context 'when the subject responds to #words' do
              context 'and #words responds to #size' do
                let(:source) do
                  <<-END
                    class String
                      def words
                        split(' ')
                      end
                    end

                    describe 'a string' do
                      it 'has 2 words' do
                        expect(subject).to have(2).words
                      end
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
                        expect(subject.words.size).to eq(2)
                      end
                    end
                  END
                end

                it 'converts into `expect(subject.words.size).to eq(2)` form' do
                  have_object.convert_to_standard_expectation!
                  rewritten_source.should == expected_source
                end

                it 'adds record "`expect(obj).to have(n).words` -> `expect(obj.words.size).to eq(n)`"' do
                  have_object.convert_to_standard_expectation!
                  record.original_syntax.should  == 'expect(obj).to have(n).words'
                  record.converted_syntax.should == 'expect(obj.words.size).to eq(n)'
                end
              end

              context 'and #words responds to only #count' do
                let(:source) do
                  <<-END
                    class String
                      def words
                        Words.new
                      end
                    end

                    class Words
                      def count
                        2
                      end
                    end

                    describe 'a string' do
                      it 'has 2 words' do
                        expect(subject).to have(2).words
                      end
                    end
                  END
                end

                let(:expected_source) do
                  <<-END
                    class String
                      def words
                        Words.new
                      end
                    end

                    class Words
                      def count
                        2
                      end
                    end

                    describe 'a string' do
                      it 'has 2 words' do
                        expect(subject.words.count).to eq(2)
                      end
                    end
                  END
                end

                it 'converts into `expect(subject.words.count).to eq(2)` form' do
                  have_object.convert_to_standard_expectation!
                  rewritten_source.should == expected_source
                end

                it 'adds record "`expect(obj).to have(n).words` -> `expect(obj.words.count).to eq(n)`"' do
                  have_object.convert_to_standard_expectation!
                  record.original_syntax.should  == 'expect(obj).to have(n).words'
                  record.converted_syntax.should == 'expect(obj.words.count).to eq(n)'
                end
              end
            end

            context 'when the subject does not respond to #words' do
              context 'and the subject responds to any of #size, #count, #length' do
                let(:source) do
                  <<-END
                    describe ['an', 'array'] do
                      it 'has 2 words' do
                        expect(subject).to have(2).words
                      end
                    end
                  END
                end

                let(:expected_source) do
                  <<-END
                    describe ['an', 'array'] do
                      it 'has 2 words' do
                        expect(subject.size).to eq(2)
                      end
                    end
                  END
                end

                it 'converts into `expect(subject.size).to eq(2)` form' do
                  have_object.convert_to_standard_expectation!
                  rewritten_source.should == expected_source
                end

                it 'adds record "`expect(collection).to have(n).items` -> `expect(collection.size).to eq(n)`"' do
                  have_object.convert_to_standard_expectation!
                  record.original_syntax.should  == 'expect(collection).to have(n).items'
                  record.converted_syntax.should == 'expect(collection.size).to eq(n)'
                end
              end

              context 'and the subject responds to none of #size, #count, #length' do
                let(:source) do
                  <<-END
                    class Sentence
                      private
                      def words
                        [1, 2]
                      end
                    end

                    describe Sentence do
                      it 'has 2 words' do
                        expect(subject).to have(2).words
                      end
                    end
                  END
                end

                let(:expected_source) do
                  <<-END
                    class Sentence
                      private
                      def words
                        [1, 2]
                      end
                    end

                    describe Sentence do
                      it 'has 2 words' do
                        expect(subject.send(:words).size).to eq(2)
                      end
                    end
                  END
                end

                it 'converts into `expect(subject.send(:words).size).to eq(2)` form' do
                  have_object.convert_to_standard_expectation!
                  rewritten_source.should == expected_source
                end

                it 'adds record "`expect(obj).to have(n).words` -> `expect(obj.send(:words).size).to eq(n)`"' do
                  have_object.convert_to_standard_expectation!
                  record.original_syntax.should  == 'expect(obj).to have(n).words'
                  record.converted_syntax.should == 'expect(obj.send(:words).size).to eq(n)'
                end
              end
            end
          end

          context 'without runtime information' do
            let(:source) do
              <<-END
                class String
                  def words
                    split(' ')
                  end
                end

                describe 'a string' do
                  it 'has 2 words' do
                    expect(subject).to have(2).words
                  end
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
                    expect(subject.size).to eq(2)
                  end
                end
              END
            end

            it 'converts into `expect(subject.size).to eq(2)` form' do
              have_object.convert_to_standard_expectation!
              rewritten_source.should == expected_source
            end

            it 'adds record "`expect(collection).to have(n).items` -> `expect(collection.size).to eq(n)`"' do
              have_object.convert_to_standard_expectation!
              record.original_syntax.should  == 'expect(collection).to have(n).items'
              record.converted_syntax.should == 'expect(collection.size).to eq(n)'
            end
          end
        end
      end
    end
  end
end
