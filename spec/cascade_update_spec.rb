require_relative './spec_helper.rb'

RSpec.describe Elasticsearch::Model::CascadeUpdate, type: :model do
  @@counter = 0

  before do
    @clz = Article.dup
    eval("ArticleD#{@@counter} = @clz")
    @clz.table_name = 'articles'

    @dep_clz = Review.dup
    eval("ReviewD#{@@counter} = @dep_clz")
    @dep_clz.table_name = 'reviews'

    @@counter += 1

    review_class = @dep_clz
    @clz.class_eval do
      has_many :reviews, class_name: review_class.name, foreign_key: 'article_id', inverse_of: :article
    end

    article_class = @clz
    @dep_clz.class_eval do
      belongs_to :article, class_name: article_class.name, foreign_key: 'article_id', inverse_of: :reviews
    end

    @clz.__send__ :include, Elasticsearch::Model
    @clz.__send__ :include, Elasticsearch::Model::Callbacks
    @clz.__send__ :include, Elasticsearch::Model::CascadeUpdate
  end

  context 'attrs' do
    describe 'load'  do
      before do
        @clz.class_eval do 
          es_register_attrs :title, :content
        end

        @article = @clz.new(title: 'nani', content: 'oops')
      end

      it { expect(@article.as_indexed_json).to eq({"title"=>"nani", "content"=>"oops"}) }
    end

    describe 'silent' do
      before do
        @clz.class_eval do 
          es_register_silent_attrs :title
          es_register_attrs :content, explicit_title: lambda {|o| o.title}
        end

        @article = @clz.new(title: 'nani', content: 'oops')
      end

      it { expect(@article.as_indexed_json(include: [:title])).to eq({
        "explicit_title"=>"nani", "content"=>"oops", "title" => "nani"
      }) }
    end
  end

  context 'assoc' do
    before do
      @article = @clz.create!(title: 'nani', content: 'oops')
      @article.reviews.create!(content: 'review 1')
      @article.reviews.create!(content: 'review 2')
    end

    describe 'basis' do
      before do
        @clz.class_eval do
          es_register_assoc :reviews, reverse_relationship: 'article'
        end
      end

      it { expect(@article.as_indexed_json).to eq({
        "reviews"=>[{"id"=>1, "article_id"=>1, "content"=>"review 1", "nonsense"=>nil}, 
                    {"id"=>2, "article_id"=>1, "content"=>"review 2", "nonsense"=>nil}]
      }) }
    end

    describe 'blk passed in' do
      before do
        @clz.class_eval do
          es_register_assoc :reviews, reverse_relationship: 'article' do |review|
            review.as_json(only: [:content])
          end
        end
      end

      it { expect(@article.as_indexed_json).to eq({
        "reviews"=>[ {"content"=>"review 1"}, 
                     {"content"=>"review 2"}]
      }) }
    end

    describe 'reverse' do
      context '#reverse_relationship' do
        before do
          @clz.class_eval do
            es_register_attrs :title
            es_register_assoc :reviews, reverse_relationship: 'article' do |review|
              review.as_json(only: [:content])
            end
          end

        end

        it do 
          expect(@article.__elasticsearch__).to receive(:update_document_attributes).with(
            "reviews"=>[ {"content"=>"review 1"}, 
                         {"content"=>"review 2 changed"}]
          )

          @review = @article.reviews[1]
          @review.content = 'review 2 changed'
          @review.save!
        end
      end

      context '#reverse_trigger' do
        before do
          @clz.class_eval do
            es_register_attrs :title
            es_register_assoc(:reviews, reverse_relationship: 'article', 
                              reverse_trigger: lambda {|review, changes| changes.has_key? :content }
                             ) do |review|
              review.as_json(only: [:content])
            end
          end
        end

        describe 'include changed key' do
          it do 
            expect(@article.__elasticsearch__).to receive(:update_document_attributes).with(
              "reviews"=>[ {"content"=>"review 1"}, 
                           {"content"=>"review 2 changed"}]
            )

            @review = @article.reviews[1]
            @review.content = 'review 2 changed'
            @review.save!
          end
        end

        describe 'exclude changed key' do
          it do 
            expect(@article.__elasticsearch__).to receive(:update_document_attributes).never

            @review = @article.reviews[1]
            @review.nonsense = 'change does not matter much'
            @review.save!
          end
        end
      end
    end
  end
end
