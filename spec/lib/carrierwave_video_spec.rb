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
      TestVideoUploader.should_receive(:process).with(encode_video: ["format", :opts])
      TestVideoUploader.encode_video("format", :opts)
    end

    it "does not require options" do
      TestVideoUploader.should_receive(:process).with(encode_video: ["format", {}])
      TestVideoUploader.encode_video("format")
    end
  end

  describe "#encode_video" do
    let(:format) { 'webm' }
    let(:movie) { mock }

    before do
      converter.stub(:current_path).and_return('video/path/file.mov')

      FFMPEG::Movie.should_receive(:new).and_return(movie)
    end

    context "no options set" do
      before {  File.should_receive(:rename) }
      it "is calls transcode with correct format options" do
        movie.should_receive(:transcode) do |path, opts, codec_opts|
          codec_opts.should == {preserve_aspect_ratio: :width}

          opts[:video_codec].should == 'libvpx'
          opts[:audio_codec].should == 'libvorbis'
          opts[:custom].should == '-b 1500k -ab 160000 -f webm -g 30 '

          path.should == "video/path/tmpfile.#{format}"
        end

        converter.encode_video(format)
      end
    end

    context "callbacks set" do
      before { movie.should_receive(:transcode) }

      context "no exceptions raised" do
        before {  File.should_receive(:rename) }

        it "calls before_transcode, after_transcode, and ensure" do
          converter.model.should_receive(:method1).ordered
          converter.model.should_receive(:method2).ordered
          converter.model.should_receive(:method3).ordered

          converter.encode_video(format, callbacks: {
                                 before_transcode: :method1,
                                 after_transcode: :method2,
                                 ensure: :method3
          })
        end
      end

      context "exception raised" do
        let(:e) { StandardError.new("test error") }
        before { File.should_receive(:rename).and_raise(e) }

        it "calls before_transcode and ensure" do
          converter.model.should_receive(:method1).ordered
          converter.model.should_not_receive(:method2)
          converter.model.should_receive(:method3).ordered

          lambda do
            converter.encode_video(format, callbacks: {
                                   before_transcode: :method1,
                                   after_transcode: :method2,
                                   ensure: :method3
            })
          end.should raise_exception(e)
        end
      end
    end

    context "logger set" do
      let(:logger) { mock }
      before do
        converter.model.stub(:logger).and_return(logger)
        movie.should_receive(:transcode)
      end

      context "with no exceptions" do
        before { File.should_receive(:rename) }

        it "sets FFMPEG logger to logger and resets" do
          old_logger = ::FFMPEG.logger
          ::FFMPEG.should_receive(:logger=).with(logger).ordered
          ::FFMPEG.should_receive(:logger=).with(old_logger).ordered
          converter.encode_video(format, logger: :logger)
        end
      end

      context "with exceptions" do
        let(:e) { StandardError.new("test error") }
        before { File.should_receive(:rename).and_raise(e) }

        it "logs exception" do
          lambda do
            converter.encode_video(format, logger: :logger)
          end.should raise_exception(e)
        end
      end
    end

    context "watermark set" do
      before { File.should_receive(:rename) }

      it "appends watermark params to custom params for ffmpeg" do
        movie.should_receive(:transcode) do |path, opts, codec_opts|
          codec_opts.should == {preserve_aspect_ratio: :width}

          opts[:video_codec].should == 'libvpx'
          opts[:audio_codec].should == 'libvorbis'
          opts[:custom].should == "-b 1500k -ab 160000 -f webm -g 30 -vf \"movie=path/to/file.png [logo]; [in][logo] overlay=5:main_h-overlay_h-5 [out]\""

          path.should == "video/path/tmpfile.#{format}"
        end

        converter.encode_video(format, watermark: {
          path: 'path/to/file.png',
          position: :bottom_left,
          pixels_from_edge: 5
        })
      end

      it "only requires path watermark parameter" do
        movie.should_receive(:transcode) do |path, opts, codec_opts|
          codec_opts.should == {preserve_aspect_ratio: :width}

          opts[:video_codec].should == 'libvpx'
          opts[:audio_codec].should == 'libvorbis'
          opts[:custom].should == "-b 1500k -ab 160000 -f webm -g 30 -vf \"movie=path/to/file.png [logo]; [in][logo] overlay= [out]\""

          path.should == "video/path/tmpfile.#{format}"
        end

        converter.encode_video(format, watermark: {
          path: 'path/to/file.png'
        })
      end
    end
  end
end
