require 'spec_helper'

describe CarrierWave::Video do
  class Video; end

  class TestVideoUploader
    include CarrierWave::Video
    def cached?; end
    def cache_stored_file!; end
    def model
      @video ||= Video.new
    end
  end

  let(:converter) { TestVideoUploader.new }

  describe ".encode_video" do
    it "processes the model" do
      expect(TestVideoUploader).to receive(:process).with(encode_video: ["format", :opts])
      TestVideoUploader.encode_video("format", :opts)
    end

    it "does not require options" do
      expect(TestVideoUploader).to receive(:process).with(encode_video: ["format", {}])
      TestVideoUploader.encode_video("format")
    end
  end

  describe ".encode_ogv" do
    it "processes the model" do
      expect(TestVideoUploader).to receive(:process).with(encode_ogv: [:opts])
      TestVideoUploader.encode_ogv(:opts)
    end

    it "does not require options" do
      expect(TestVideoUploader).to receive(:process).with(encode_ogv: [{}])
      TestVideoUploader.encode_ogv
    end
  end

  describe "#encode_video" do
    let(:format) { 'webm' }
    let(:movie) { double }

    before do
      allow(converter).to receive(:current_path).and_return('video/path/file.mov')

      expect(FFMPEG::Movie).to receive(:new).and_return(movie)
    end

    context "with no options set" do
      before {  expect(File).to receive(:rename) }

      it "calls transcode with correct format options" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(codec_opts).to eq({preserve_aspect_ratio: :width})

          expect(opts[:video_codec]).to eq('libvpx')
          expect(opts[:audio_codec]).to eq('libvorbis')
          expect(opts[:custom]).to eq(%w(-b 1500k -ab 160000 -f webm))

          expect(path).to eq("video/path/tmpfile.#{format}")
        end

        converter.encode_video(format)
      end

      it "provides a default for the resolution" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(opts[:resolution]).to eq('640x360')
        end

        converter.encode_video(format)
      end
    end

    context "with callbacks set" do
      before { expect(movie).to receive(:transcode) }
      let(:opts) do
        { callbacks: {
             before_transcode: :method1,
             after_transcode: :method2,
             rescue: :method3,
             ensure: :method4
          }
        }
      end

      context "no exceptions raised" do
        before {  expect(File).to receive(:rename) }

        it "calls before_transcode, after_transcode, and ensure" do
          expect(converter.model).to receive(:method1).with(format, opts).ordered
          expect(converter.model).to receive(:method2).with(format, opts).ordered
          expect(converter.model).not_to receive(:method3)
          expect(converter.model).to receive(:method4).with(format, opts).ordered

          converter.encode_video(format, opts)
        end
      end

      context "exception raised" do
        let(:e) { StandardError.new("test error") }
        before { expect(File).to receive(:rename).and_raise(e) }

        it "calls before_transcode and ensure" do
          expect(converter.model).to receive(:method1).with(format, opts).ordered
          expect(converter.model).not_to receive(:method2)
          expect(converter.model).to receive(:method3).with(format, opts).ordered
          expect(converter.model).to receive(:method4).with(format, opts).ordered

          expect do
            converter.encode_video(format, opts)
          end.to raise_exception(e.class)
        end
      end
    end

    context "with logger set" do
      let(:logger) { double }
      before do
        allow(converter.model).to receive(:logger).and_return(logger)
        expect(movie).to receive(:transcode)
      end

      context "with no exceptions" do
        before { expect(File).to receive(:rename) }

        it "sets FFMPEG logger to logger and resets" do
          old_logger = ::FFMPEG.logger
          expect(::FFMPEG).to receive(:logger=).with(logger).ordered
          expect(::FFMPEG).to receive(:logger=).with(old_logger).ordered
          converter.encode_video(format, logger: :logger)
        end
      end

      context "with exceptions" do
        let(:e) { StandardError.new("test error") }
        before { expect(File).to receive(:rename).and_raise(e) }

        it "logs exception" do
          expect(logger).to receive(:error).with("#{e.class}: #{e.message}")
          allow(logger).to receive(:error) #backtrace

          expect do
            converter.encode_video(format, logger: :logger)
          end.to raise_exception(e.class)
        end
      end
    end

    context "with progress set" do
      before do
        expect(File).to receive(:rename)
        allow(movie).to receive(:transcode).and_yield(0.0).and_yield(1.0)
      end
      let(:opts) { {progress: :progress} }

      it "logs progress" do
        expect(converter.model).to receive(:progress).with(0.0)
        expect(converter.model).to receive(:progress).with(1.0)
        converter.encode_video(format, progress: :progress)
      end

      it "logs progress with format and options" do
        allow(converter.model).to receive_message_chain(:method, :arity).and_return(3)
        expect(converter.model).to receive(:progress).with(format, hash_including(opts), 0.0)
        expect(converter.model).to receive(:progress).with(format, hash_including(opts), 1.0)
        converter.encode_video(format, opts)
      end
    end

    context "with watermark set" do
      before { expect(File).to receive(:rename) }

      it "appends watermark params to custom params for ffmpeg" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(codec_opts).to eq({preserve_aspect_ratio: :width})

          expect(opts[:video_codec]).to eq('libvpx')
          expect(opts[:audio_codec]).to eq('libvorbis')
          expect(opts[:custom]).to eq(["-b","1500k","-ab","160000","-f","webm","-vf","\"movie=path/to/file.png [logo]; [in][logo] overlay=5:main_h-overlay_h-5 [out]\""])

          expect(path).to eq("video/path/tmpfile.#{format}")
        end

        converter.encode_video(format, watermark: {
          path: 'path/to/file.png',
          position: :bottom_left,
          pixels_from_edge: 5
        })
      end

      it "only requires path watermark parameter" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(codec_opts).to eq({preserve_aspect_ratio: :width})

          expect(opts[:video_codec]).to eq('libvpx')
          expect(opts[:audio_codec]).to eq('libvorbis')
          expect(opts[:custom]).to eq(["-b","1500k","-ab","160000","-f","webm","-vf","\"movie=path/to/file.png [logo]; [in][logo] overlay= [out]\""])

          expect(path).to eq("video/path/tmpfile.#{format}")
        end

        converter.encode_video(format, watermark: {
          path: 'path/to/file.png'
        })
      end

      it "removes watermark options from common options" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(opts).not_to have_key(:watermark)
        end

        converter.encode_video(format, watermark: {
          path: 'path/to/file.png',
          position: :bottom_left,
          pixels_from_edge: 5
        })
      end
    end

    context "with resolution set to :same" do
      before do
        expect(File).to receive(:rename)
        allow(movie).to receive(:resolution).and_return('1280x720')
      end

      it "sets the output resolution to match that of the input" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(opts[:resolution]).to eq('1280x720')
        end

        converter.encode_video(format, resolution: :same)
      end
    end

    context "with custom passed in" do
      before do
        expect(File).to receive(:rename)
      end

      it "takes the provided custom param" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(opts[:custom]).to eq(%w(-preset slow)) # a la changes in ffmpeg 0.11.1
        end

        converter.encode_video(format, custom: %w(-preset slow))
      end

      it "maintains the watermark params" do
        expect(movie).to receive(:transcode) do |path, opts, codec_opts|
          expect(opts[:custom]).to eq(["-preset","slow","-vf","\"movie=path/to/file.png [logo]; [in][logo] overlay= [out]\""])
        end

        converter.encode_video(format, custom: %w(-preset slow), watermark: {
          path: 'path/to/file.png'
        })
      end
    end

    context "given a block" do
      let(:movie) { double }
      let(:opts) { {} }
      let(:params) { { resolution: "640x360", watermark: {}, video_codec: "libvpx", audio_codec: "libvorbis", custom: %w(-b 1500k -ab 160000 -f webm) } }

      before do
        expect(File).to receive(:rename)
        allow(movie).to receive(:resolution).and_return('1280x720')
      end

      it "calls the block, with the movie file and params" do
        expect(movie).to receive(:transcode) do |path, format_opts, codec_opts|
          expect(format_opts[:video_codec]).to eq('libvpx')
          expect(format_opts[:audio_codec]).to eq('libvorbis')
        end

        expect {
          |block| converter.encode_video(format, opts, &block)
        }.to yield_with_args(movie, params)
      end

      it "allows the block to modify the params" do
        block = Proc.new { |input, params| params[:custom] = %w(-preset slow) }

        expect(movie).to receive(:transcode) do |path, format_opts, codec_opts|
          expect(format_opts[:custom]).to eq(%w(-preset slow))
        end

        converter.encode_video(format, opts, &block)
      end

      it "evaluates the final params after any modifications" do
        block = Proc.new do |input, params|
          params[:custom] = %w(-preset slow)
          params[:watermark][:path] = 'customized/path'
        end

        expect(movie).to receive(:transcode) do |path, format_opts, codec_opts|
          expect(format_opts[:custom]).to eq(["-preset","slow","-vf","\"movie=customized/path [logo]; [in][logo] overlay= [out]\""])
        end

        converter.encode_video(format, opts, &block)
      end

      it "gives preference to the block-provided settings" do
        opts = { resolution: :same }

        block = Proc.new do |input, params|
          params[:resolution] = '1x1'
        end

        expect(movie).to receive(:transcode) do |path, format_opts, codec_opts|
          expect(format_opts[:resolution]).to eq('1x1')
        end

        converter.encode_video(format, opts, &block)
      end
    end
  end

  describe "#encode_ogv" do
    let(:movie) { double }
    let(:output_path) { 'video/path/tmpfile.ogv' }
    let(:movie_path) { 'video/path/input.mov' }
    let(:logger) { double(:logger) }


    before do
      allow(converter.model).to receive(:logger).and_return(logger)
      expect(File).to receive(:rename)
      allow(converter).to receive(:current_path).and_return('video/path/input.mov')
    end

    context "no options set" do
      it "calls transcode with correct format options" do
        transcoder = double(:transcoder)
        expect(CarrierWave::Video::FfmpegTheora).to receive(:new).with(movie_path, output_path).and_return(transcoder)
        expect(transcoder).to receive(:run)

        converter.encode_ogv({})
      end
    end

    context "with logger set" do
      before do
        allow(converter.model).to receive(:logger).and_return(logger)
      end

      it "calls transcode with correct format options and passes logger to transcoder" do
        transcoder = double(:transcoder)
        expect(CarrierWave::Video::FfmpegTheora).to receive(:new).with(movie_path, output_path).and_return(transcoder)
        expect(transcoder).to receive(:run).with(logger)

        converter.encode_ogv({logger: :logger})
      end
    end
  end

end
