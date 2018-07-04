describe Magritte::Code do
  describe 'a single pipe' do
    let(:code) {
      Magritte::Code.new do
        s { put 1 }.p { put(5 + get) }.go
        put 10
      end
    }

    let(:output) {
      code.spawn_collect
    }

    it 'successfully pipes' do
      assert { output == [6, 10] }
    end
  end

  describe 'multiple pipes' do
    let(:code) {
      Magritte::Code.new do
        s { put 1; put 2 }.p { put(get + get) }.p { put(get * 2) }.go
        put 10
      end
    }

    let(:output) {
      code.spawn_collect
    }

    it 'successfully pipes' do
      assert { output == [6, 10] }
    end
  end
end
