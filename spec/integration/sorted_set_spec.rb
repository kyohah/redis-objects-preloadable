# frozen_string_literal: true

RSpec.describe "sorted_set preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }
  let!(:w3) { Widget.create!(name: "w3") }

  before do
    w1.ranking["alice"] = 100.0
    w1.ranking["bob"]   = 200.0
    w2.ranking["carol"] = 50.0
    # w3 has no sorted_set entries
  end

  it "preloads sorted_set members via pipeline" do
    records = Widget.where(id: [w1.id, w2.id, w3.id]).redis_preload(:ranking).load

    expect(records.find { |r| r.id == w1.id }.ranking.members).to contain_exactly("alice", "bob")
    expect(records.find { |r| r.id == w2.id }.ranking.members).to eq(["carol"])
    expect(records.find { |r| r.id == w3.id }.ranking.members).to eq([])
  end

  it "supports score lookup" do
    records = Widget.where(id: w1.id).redis_preload(:ranking).load
    ranking = records.first.ranking

    expect(ranking.score("alice")).to eq(100.0)
    expect(ranking.score("bob")).to eq(200.0)
    expect(ranking.score("missing")).to be_nil
  end

  it "supports rank lookup" do
    records = Widget.where(id: w1.id).redis_preload(:ranking).load
    ranking = records.first.ranking

    expect(ranking.rank("alice")).to eq(0)
    expect(ranking.rank("bob")).to eq(1)
    expect(ranking.rank("missing")).to be_nil
  end

  it "supports length" do
    records = Widget.where(id: [w1.id, w3.id]).redis_preload(:ranking).load

    expect(records.find { |r| r.id == w1.id }.ranking.length).to eq(2)
    expect(records.find { |r| r.id == w3.id }.ranking.length).to eq(0)
  end
end
