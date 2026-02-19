# frozen_string_literal: true

RSpec.describe "mixed type preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }

  before do
    w1.view_count.increment(5)
    w1.recent_ids << "10"
    w1.recent_ids << "20"
    w1.tag_ids << "ruby"
    w1.metadata.bulk_set("env" => "prod")

    w2.view_count.increment(15)
    w2.tag_ids << "python"
  end

  it "preloads multiple types simultaneously" do
    records = Widget.where(id: [w1.id, w2.id])
                    .redis_preload(:view_count, :recent_ids, :tag_ids, :metadata)
                    .load

    loaded_w1 = records.find { |r| r.id == w1.id }
    loaded_w2 = records.find { |r| r.id == w2.id }

    expect(loaded_w1.view_count.value).to eq(5)
    expect(loaded_w1.recent_ids.value).to contain_exactly("10", "20")
    expect(loaded_w1.tag_ids.members).to contain_exactly("ruby")
    expect(loaded_w1.metadata.all).to eq("env" => "prod")

    expect(loaded_w2.view_count.value).to eq(15)
    expect(loaded_w2.recent_ids.value).to eq([])
    expect(loaded_w2.tag_ids.members).to contain_exactly("python")
    expect(loaded_w2.metadata.all).to eq({})
  end

  it "works without redis_preload (fallback)" do
    records = Widget.where(id: w1.id).load

    expect(records.first.view_count.value).to eq(5)
    expect(records.first.recent_ids.value).to contain_exactly("10", "20")
  end

  it "chains with where/order/limit" do
    records = Widget.where(name: %w[w1 w2])
                    .order(:id)
                    .redis_preload(:view_count, :tag_ids)
                    .limit(10)
                    .load

    expect(records.size).to eq(2)
    expect(records.first.view_count.value).to eq(5)
    expect(records.last.view_count.value).to eq(15)
  end
end
