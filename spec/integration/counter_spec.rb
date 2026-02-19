# frozen_string_literal: true

RSpec.describe "counter preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }
  let!(:w3) { Widget.create!(name: "w3") }

  before do
    w1.view_count.increment(10)
    w2.view_count.increment(20)
    # w3 has no counter set
  end

  it "preloads counter values via MGET" do
    records = Widget.where(id: [w1.id, w2.id, w3.id]).redis_preload(:view_count).load

    expect(records.find { |r| r.id == w1.id }.view_count.value).to eq(10)
    expect(records.find { |r| r.id == w2.id }.view_count.value).to eq(20)
    expect(records.find { |r| r.id == w3.id }.view_count.value).to eq(0)
  end

  it "returns 0 for non-existent counter keys" do
    records = Widget.where(id: w3.id).redis_preload(:view_count).load

    expect(records.first.view_count.value).to eq(0)
  end

  it "reports nil? correctly" do
    records = Widget.where(id: [w1.id, w3.id]).redis_preload(:view_count).load

    loaded_w1 = records.find { |r| r.id == w1.id }
    loaded_w3 = records.find { |r| r.id == w3.id }

    expect(loaded_w1.view_count.nil?).to be false
    expect(loaded_w3.view_count.nil?).to be true
  end

  it "resolves lazily on first access, not on load" do
    redis = Redis::Objects.redis
    allow(redis).to receive(:mget).and_call_original

    records = Widget.where(id: [w1.id, w2.id]).redis_preload(:view_count).load

    # load itself should NOT trigger MGET
    expect(redis).not_to have_received(:mget)

    # First access triggers resolve
    expect(records.first.view_count.value).to be_a(Integer)
    expect(redis).to have_received(:mget).once
  end
end
