# coding: utf-8

require 'spec_helper'
require 'transpec/dynamic_analyzer/rewriter'

module Transpec
  class DynamicAnalyzer
    describe Rewriter do
      subject(:rewriter) { Rewriter.new }

      describe '#rewrite' do
        subject { rewriter.rewrite(source) }

        let(:source) do
          <<-END
            it 'matches to foo' do
              subject.should =~ foo
            end
          END
        end

        let(:expected_source) do
          <<-END
            it 'matches to foo' do
              subject.should =~ transpec_analysis(foo, self, __FILE__, 2, 32)
            end
          END
        end

        it 'wraps target object with analysis helper method' do
          should == expected_source
        end
      end
    end
  end
end
