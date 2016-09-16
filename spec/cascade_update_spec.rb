require_relative './spec_helper.rb'

RSpec.describe Elasticsearch::Model::CascadeUpdate, type: :model do
  before :all do
    Article.__send__ :include, Elasticsearch::Model::CascadeUpdate
  end

  context 'Registr attrs'  do
    before do
      Article.class_eval do 
        es_register_attrs :title, :content
      end
    end

    it 'works' do
      a = Article.new(title: 'nani', content: 'oops')
      expect(a.as_indexed_json).to eq({"title"=>"nani", "content"=>"oops"})
    end
  end
end
