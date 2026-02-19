# frozen_string_literal: true

RSpec.describe "association preloading with .preload" do
  let!(:user1) { User.create!(name: "alice") }
  let!(:user2) { User.create!(name: "bob") }
  let!(:a1) { Article.create!(user: user1, title: "post1") }
  let!(:a2) { Article.create!(user: user1, title: "post2") }
  let!(:a3) { Article.create!(user: user2, title: "post3") }

  before do
    a1.view_count.increment(10)
    a2.view_count.increment(20)
    a3.view_count.increment(30)
    a1.cached_summary.value = "summary1"
    a3.cached_summary.value = "summary3"
  end

  it "preloads redis attributes on association-loaded records" do
    users = User.includes(:articles).where(id: [user1.id, user2.id]).load
    articles = users.flat_map(&:articles)

    Redis::Objects::Preloadable.preload(articles, :view_count, :cached_summary)

    expect(articles.find { |a| a.id == a1.id }.view_count.value).to eq(10)
    expect(articles.find { |a| a.id == a2.id }.view_count.value).to eq(20)
    expect(articles.find { |a| a.id == a3.id }.view_count.value).to eq(30)
    expect(articles.find { |a| a.id == a1.id }.cached_summary.value).to eq("summary1")
    expect(articles.find { |a| a.id == a2.id }.cached_summary.value).to be_nil
    expect(articles.find { |a| a.id == a3.id }.cached_summary.value).to eq("summary3")
  end

  it "resolves lazily on first access" do
    users = User.includes(:articles).load
    articles = users.flat_map(&:articles)

    redis = Redis::Objects.redis
    allow(redis).to receive(:mget).and_call_original

    Redis::Objects::Preloadable.preload(articles, :view_count)

    # Not yet resolved
    expect(redis).not_to have_received(:mget)

    # First access triggers batch load
    articles.first.view_count.value
    expect(redis).to have_received(:mget).once
  end

  it "returns the records array" do
    articles = [a1, a2]
    result = Redis::Objects::Preloadable.preload(articles, :view_count)
    expect(result).to eq(articles)
  end

  it "handles empty records" do
    result = Redis::Objects::Preloadable.preload([], :view_count)
    expect(result).to eq([])
  end
end
