# frozen_string_literal: true
describe Stupidedi::Reader::Pointer do
  using Stupidedi::Refinements

  def pointer(value)
    Stupidedi::Reader::Pointer.build(value)
  end

  def pointer_(*args)
    Stupidedi::Reader::Pointer.new(args)
  end

  def prefix(pointer)
    pointer.storage[0, pointer.offset]
  end

  def suffix(pointer)
    pointer.storage[pointer.offset + pointer.length..-1]
  end

  let(:three) { pointer([5,0,1]) }
  let(:empty) { pointer([])      }

  describe ".build" do
    context "when value is a String" do
      specify { expect(pointer("abc")).to be_a(Stupidedi::Reader::Pointer) }

      allocation do
        storage = "X"
        expect{ pointer(storage) }.to allocate(Stupidedi::Reader::Substring => 1)
      end
    end

    context "when value is an Array" do
      specify { expect(pointer([5,6])).to be_a(Stupidedi::Reader::Pointer) }

      allocation do
        storage = [1,2]
        expect{ pointer(storage) }.to allocate(Stupidedi::Reader::Pointer => 1)
      end
    end

    context "when value is a Pointer" do
      specify do
        p = pointer("xyz")
        expect(pointer(p)).to equal(p)

        q = pointer([5,6])
        expect(pointer(q)).to equal(q)
      end
    end

    todo "when value is a compatible type"

    todo "when value is an incompatible type"

    context "when offset is negative" do
      specify { expect{ pointer_("xxx", -1, 0) }.to raise_error(ArgumentError) }
    end

    context "when offset exceeds length" do
      specify { expect{ pointer_("xxx", 4, 0) }.to raise_error(ArgumentError) }
    end

    context "when length is negative" do
      specify { expect{ pointer_("xxx", 0, -1) }.to raise_error(ArgumentError) }
    end

    context "when length exceeds storage length" do
      specify { expect{ pointer_("xxx", 0, 4) }.to raise_error(ArgumentError) }
    end
  end

  todo "#inspect"

  describe "#reify" do
    context "when storage is frozen" do
      let(:abcdef) { pointer("abcdef".freeze) }

      context "and storage spans entire storage" do
        allocation { p = abcdef; expect{ p.send(:reify)        }.to allocate(String: 0) }
        allocation { p = abcdef; expect{ p.send(:reify, false) }.to allocate(String: 0) }

        context "but always_allocate is true" do
          allocation { p = abcdef; expect{ p.send(:reify, true) }.to allocate(String: 1) }
        end
      end

      context "and storage does not span entire storage" do
        allocate { p = abcdef.drop(1); expect{ p.send(:reify) }.to allocate(String: 1) }
        allocate { p = abcdef.take(1); expect{ p.send(:reify) }.to allocate(String: 1) }
      end
    end

    todo "when storage is not frozen" do
    end
  end

  describe "#empty?" do
    specify { expect(empty).to be_empty }
    specify { expect(three).to_not be_empty }
  end

  describe "#blank?" do
    specify { expect(empty).to be_blank }
    specify { expect(three).to_not be_blank }
  end

  describe "#present?" do
    specify { expect(three).to be_present }
    specify { expect(empty).to_not be_present }
  end

  describe "#==" do
    context "when compared to self" do
      specify { p = pointer("xxx"); expect(p).to eq(p) }
    end

    context "when storage is separate" do
      context "and substring is equal" do
        specify { expect(pointer("xxx")).to eq(pointer("xxx")) }
        specify { expect(pointer("xxx")).to eq(pointer("   xxx").drop(3)) }
        specify { expect(pointer("xxx")).to eq(pointer("xxx    ").take(3)) }
        specify { expect(pointer("xxx")).to eq(pointer("   xxx    ").drop(3).take(3)) }
      end

      context "and substring is not equal" do
        specify { expect(pointer("ooo")).to_not eq(pointer("xxx")) }
        specify { expect(pointer("ooo")).to_not eq(pointer("    xxx").drop(3)) }
        specify { expect(pointer("ooo")).to_not eq(pointer("xxx    ").take(3)) }
        specify { expect(pointer("ooo")).to_not eq(pointer("   xxx    ").drop(3).take(3)) }
      end
    end

    context "when storage is shared" do
      context "and substring is equal" do
        let(:p) { pointer("xxxoooxxx") }
        specify { expect(p.take(3)).to eq(p.take(3)) }
        specify { expect(p.take(3)).to eq(p.drop(6)) }
        specify { expect(p.take(3)).to eq(p.drop(6)) }
      end

      context "and substring is not equal" do
        let(:p) { pointer("oooxxxooo") }
        specify { expect(p.take(3)).to eq(p.take(3)) }
        specify { expect(p.take(3)).to eq(p.drop(6)) }
        specify { expect(p.take(3)).to eq(p.drop(6)) }
      end
    end

    allocation do
      ooo = pointer("ooo")
      xxx = pointer("xxx")

      expect{ ooo == xxx }.to allocate(String: 0)
      expect{ ooo == ooo }.to allocate(String: 0)
    end
  end

  describe "+" do
    let(:a) { pointer("abcdefghi".dup) }

    context "when argument is a non-pointer value" do
      context "when pointer suffix starts with argument" do
        specify do
          b = a.drop(3).take(3)
          c = "gh"

          # Precondition
          expect(suffix(b)).to start_with(c)

          d = b + c
          expect(b).to eq("def")
          expect(c).to eq("gh")
          expect(d).to eq("defgh")
          expect(d).to be_a(a.class)
        end

        allocation do
          b = a.drop(3).take(3)
          c = "gh"
          expect(suffix(b)).to start_with(c)
          expect{ b + c }.to allocate(String: 0, a.class => 1)
        end
      end

      context "when argument is pointer suffix plus more" do
        specify do
          b = a.drop(3).take(3)
          c = "ghijkl"

          # Precondition
          expect(c).to start_with(suffix(b))
          expect(c).to_not eq(suffix(b))

          d = b + c
          expect(a).to eq("abcdefghi")
          expect(b).to eq("def")
          expect(c).to eq("ghijkl")
          expect(d).to eq("defghijkl")
          expect(d).to be_a(c.class)
        end

        allocation do
          b = a.drop(3).take(3)
          c = "ghijkl"
          expect(c).to start_with(suffix(b))
          expect(c).to_not eq(suffix(b))
          expect{ b + c }.to allocate(c.class => 1)
        end
      end

      context "when argument is not pointer suffix" do
        specify do
          b = a.take(6)
          c = "xxx"

          # Precondition
          expect(a.storage).to be_frozen

          d = b + c
          expect(a).to eq("abcdefghi")
          expect(b).to eq("abcdef")
          expect(c).to eq("xxx")
          expect(d).to eq("abcdefxxx")
          expect(d).to be_a(c.class)
        end

        allocation do
          b = a.take(6)
          c = "xxx"
          expect(a.storage).to be_frozen
          expect{ b + c }.to allocate(c.class => 1)
        end
      end
    end

    context "when argument is a string pointer" do
      context "when pointer suffix starts with argument" do
        specify do
          b = a.drop(3).take(3)
          c = pointer("gh")

          # Precondition
          expect(suffix(b)).to start_with(c)

          d = b + c
          expect(a).to eq("abcdefghi")
          expect(b).to eq("def")
          expect(c).to eq("gh")
          expect(d).to eq("defgh")
          expect(d).to be_a(a.class)
        end

        allocation do
          b = a.drop(3).take(3)
          c = pointer("gh")
          expect(suffix(b)).to start_with(c)
          expect{ b + c }.to allocate(a.class => 1)
        end
      end

      context "when argument is pointer suffix plus more" do
        specify do
          b = a.drop(3).take(3)
          c = pointer("ghijkl")

          # Precondition
          expect(c).to start_with(suffix(b))
          expect(c).to_not eq(suffix(b))

          d = b + c
          expect(a).to eq("abcdefghi")
          expect(b).to eq("def")
          expect(c).to eq("ghijkl")
          expect(d).to eq("defghijkl")
          expect(d).to be_a(String)
        end

        allocation do
          b = a.drop(3).take(3)
          c = pointer("ghijkl")
          expect(c).to start_with(suffix(b))
          expect(c).to_not eq(suffix(b))
          expect{ b + c }.to allocate(String: 1)
        end
      end

      context "when argument is not pointer suffix" do
        specify do
          b = a.take(6)
          c = pointer("xxx")

          # Precondition
          expect(suffix(b)).to_not start_with(c)

          d = b + c
          expect(a).to eq("abcdefghi")
          expect(b).to eq("abcdef")
          expect(c).to eq("xxx")
          expect(d).to eq("abcdefxxx")
          expect(d).to be_a(String)
        end

        allocation do
          b = a.take(6)
          c = pointer("xxx")
          expect(suffix(b)).to_not start_with(c)
          expect{ b + c }.to allocate(String: 1)
        end
      end
    end
  end

  describe "#head" do
  end

  describe "#last" do
  end

  describe "#defined_at?" do
  end

  describe "#at" do
  end

  describe "#tail" do
  end

  describe "#[]" do
  end

  describe "#drop" do
  end

  describe "#drop!" do
  end

  describe "take" do
  end

  context "#take!" do
  end

  describe "#drop_take" do
  end

  describe "#split_at" do
  end

  describe ".build" do
  end
end