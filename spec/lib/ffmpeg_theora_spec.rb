require 'spec_helper'

describe CarrierWave::Video::FfmpegTheora do
  describe "run" do
    let(:input_file_path) { '/tmp/file.mov' }
    let(:output_file_path) { '/tmp/file.ogv' }
    let(:binary) { 'bunnery' }

    let(:transcoder) { CarrierWave::Video::FfmpegTheora.new(input_file_path, output_file_path) }

    before do
     CarrierWave::Video.ffmpeg2theora_binary = binary
    end

    it "should run the ffmpeg2theora binary" do
      command = "#{binary} #{input_file_path} -o #{output_file_path}"
      Open3.should_receive(:popen3).with(command)

      transcoder.run
    end

    context "given a logger" do
      let(:logger) { mock(:logger) }

      it "should run and log results" do
        command = "#{binary} #{input_file_path} -o #{output_file_path}"
        Open3.should_receive(:popen3).with(command)
        logger.should_receive(:info).with("Running....#{command}")
        logger.should_receive(:error).with("Failure!")

        transcoder.run(logger)
      end
    end
  end
end
