# frozen_string_literal: true

RSpec.describe "hash_key preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }
  let!(:w3) { Widget.create!(name: "w3") }

  before do
    w1.metadata.bulk_set("color" => "red", "size" => "large")
    w2.metadata.bulk_set("color" => "blue")
    # w3 has no hash entries
  end

  it "preloads hash values via pipeline" do
    records = Widget.where(id: [w1.id, w2.id, w3.id]).redis_preload(:metadata).load

    expect(records.find { |r| r.id == w1.id }.metadata.all).to eq("color" => "red", "size" => "large")
    expect(records.find { |r| r.id == w2.id }.metadata.all).to eq("color" => "blue")
    expect(records.find { |r| r.id == w3.id }.metadata.all).to eq({})
  end

  it "supports [] access" do
    records = Widget.where(id: w1.id).redis_preload(:metadata).load
    meta = records.first.metadata

    expect(meta["color"]).to eq("red")
    expect(meta["size"]).to eq("large")
    expect(meta["missing"]).to be_nil
  end

  it "supports keys and values" do
    records = Widget.where(id: w1.id).redis_preload(:metadata).load
    meta = records.first.metadata

    expect(meta.keys).to contain_exactly("color", "size")
    expect(meta.values).to contain_exactly("red", "large")
  end
end
