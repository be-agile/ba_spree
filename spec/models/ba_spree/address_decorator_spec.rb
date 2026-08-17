require 'rails_helper'

# BaSpree::AddressDecorator の挙動を検証するスペック
#
# Address 作成時に User の名前等を上書きしていた挙動が廃止されていることを確認する。
# (User の自動補完は Spree::UserBillAddressSyncDecorator で請求先からのみ実行される)
RSpec.describe BaSpree::AddressDecorator, type: :model do
  describe "after_initialize :set_default_values" do
    let!(:user) do
      create(:user,
             first_name: "本人",
             last_name: "姓",
             phone: "090-1111-2222",
             company: "会社")
    end

    subject { Spree::Address.new(user: user) }

    it "User の値が Address にコピーされる(逆方向の既存挙動)" do
      # 注: User#set_phone により User.phone はハイフン除去された形式で保存されるため、
      # Address にコピーされる phone も normalize 後の値となる
      expect(subject.attributes).to include(
        "firstname" => "本人",
        "lastname" => "姓",
        "phone" => "09011112222",
        "company" => "会社"
      )
    end
  end

  describe "after_create :set_user_attributes(廃止されていることの確認)" do
    let!(:user) do
      create(:user, first_name: nil, last_name: nil, phone: nil, company: nil)
    end

    context "新しい Address(配送先想定)を作成した場合" do
      before do
        create(:address,
               firstname: "贈り先太郎",
               lastname: "山田",
               phone: "090-0000-1111",
               company: "贈り先会社",
               user: user)
      end

      it "User の first_name / last_name / phone / company は更新されない" do
        expect(user.reload.attributes).to include(
          "first_name" => nil,
          "last_name" => nil,
          "phone" => nil,
          "company" => nil
        )
      end
    end
  end
end
