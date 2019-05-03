#!/usr/bin/env ruby

# file: v2av.rb

require 'ostruct'
require 'subunit'
require 'zip/zip'
require 'ogginfo'
require 'wavefile'
require 'rxfhelper'
require 'pollyspeech'
require 'archive/zip'


module WavTool
  include WaveFile
    
  def wav_silence(filename, duration: 1)

    square_cycle = [0] * 100 * duration
    buffer = Buffer.new(square_cycle, Format.new(:mono, :float, 44100))

    Writer.new(filename, Format.new(:mono, :pcm_16, 22050)) do |writer|
      220.times { writer.write(buffer) }
    end

  end
  
  def wav_concat(files, save_file='audio.wav')
    
    Writer.new(save_file, Format.new(:stereo, :pcm_16, 22050)) do |writer|

      files.each do |file_name|

        Reader.new(file_name).each_buffer(samples_per_buffer=4096) do |buffer|
          writer.write(buffer)
        end

      end
    end
    
  end
  
  def ogg_to_wav(oggfile, wavfile=oggfile.sub(/\.ogg$/,'.wav'))
    
    if block_given? then
      yield(oggfile)
    else
    `oggdec #{oggfile}`
    end
    
  end

end

module TimeHelper

  refine String do
    def to_time()
      Time.strptime(self, "%H:%M:%S")
    end
  end
  
  refine Integer do
    def to_hms
      Subunit.new(units={minutes:60}, seconds: self).to_a
    end
  end

end

class V2av
  using ColouredText
  using TimeHelper
  include WavTool
  
  attr_accessor :steps, :duration

  def initialize(src, srt, working_dir: '/tmp/v2av', debug: false, 
      pollyspeech: {access_key: nil, secret_key: nil, voice_id: 'Amy', 
                 cache_filepath: '/tmp/v2av/pollyspeech/cache'})

    @source, @working_dir, @debug = src, working_dir, debug

    @steps = srt.lines.map do |x| 
      raw_time, desc = x.chomp.split(/ +/,2)
      OpenStruct.new({time: raw_time.to_i, desc: desc})
    end
    
    s = `exiftool #{src}`
    puts 's: ' + s.inspect if @debug
    #a = s[/Duration.*(\d{1,2}:\d{2}:\d{2})/,1].split(':').map(&:to_i)
    #@duration = Subunit.new(units={minutes:60, hours:60, seconds: 0}, a).to_i
    @duration = s[/Duration.*: (\d+)/,1].to_i        
    puts ('@duration: ' + @duration.inspect).debug if @debug
    
    @steps[0..-2].each.with_index do |x, i|
      x.duration = @steps[i+1].time - x.time
    end
    
    @steps.last.duration = @duration - @steps.last.time    

    @pollyspeech = PollySpeech.new(pollyspeech) if pollyspeech[:access_key]
    
  end

  def build(destination)

    if block_given? then

      yield(self)

    else

      dir = File.dirname(@source)
      file = File.basename(@source)      
      
      vid2 = File.join(@working_dir, file.sub(/\.mp4$/,'b\0'))
      trim_video @source, vid2

      vid3 = File.join(@working_dir, file.sub(/\.mp4$/,'c.avi'))

      generate_audio
      add_audio_track File.join(@working_dir, 'audio.wav'), vid2, vid3
      
      vid4 = File.join(dir, file.sub(/\.avi$/,'d\0'))
      resize_video vid3, vid4
      
      vid5 = File.join(dir, file.sub(/\.mp4$/,'e\0'))
      transcode_video(vid4, vid5)
      add_subtitles(vid5, destination)    

    end

  end

  private

  # adds the audio track to the video file
  # mp4 in avi out
  #
  def add_audio_track(audio_file, video_file, target_video)
    
    if block_given? then
      yield(audio_file, video_file, target_video)
    else
      `ffmpeg -i #{video_file} -i #{audio_file} -codec copy -shortest #{target_video} -y`
      #"ffmpeg -i #{video_file} -i #{audio_file} -codec copy -shortest #{target_video} -y"
    end
    
  end
  
  # mp4 in mp4 out
  #
  def add_subtitles(source, destination)
    
    
    subtitles = File.join(@working_dir, 's.srt')
    File.write subtitles, to_srt()
    
    if block_given? then
      yield(source, subtitles, destination)
    else
      `ffmpeg -i #{source} -i #{subtitles} -c copy -c:s mov_text #{destination} -y`
    end
    
  end    
  
  def generate_audio(wav: true)
    
    return nil unless @pollyspeech
    
    @steps.each.with_index do |x, i|
      
      puts 'x.desc: ' + x.desc.inspect if @debug
      filename = "voice#{i+1}.ogg"
      
      x.audio = filename
      file = File.join(@working_dir, filename)
      @pollyspeech.tts(x.desc.force_encoding('UTF-8'), file)
      
      x.audio_duration = OggInfo.open(file) {|ogg| ogg.length.to_i }
      
      if @debug then
        puts ('x.duration: ' + x.duration.inspect).debug
        puts ('x.audio_duration: ' + x.audio_duration.inspect).debug
      end
      
      duration = x.duration - x.audio_duration
      x.silence_duration = duration >= 0 ? duration : 0
      
      if wav then
        
        silent_file = File.join(@working_dir, "silence#{(i+1).to_s}.wav")
        puts 'x.silence_duration: ' + x.silence_duration.inspect if @debug
        wav_silence silent_file, duration: x.silence_duration        
        ogg_to_wav File.join(@working_dir, "voice#{i+1}.ogg")            
        
      end
      
      sleep 0.02
      
    end
    
    if wav then
      
      intro = File.join(@working_dir, 'intro.wav')
      wav_silence intro
      
      files = @steps.length.times.flat_map do |n|
        [
          File.join(@working_dir, "voice#{n+1}.wav"), 
          File.join(@working_dir, "silence#{n+1}.wav")
        ]
      end
      
      files.prepend intro
      
      wav_concat files, File.join(@working_dir, 'audio.wav')
    end
    
  end

  # avi in avi out
  def resize_video(source, destination)
    `ffmpeg -i #{source} -vf scale="720:-1" #{destination} -y`
  end
  
  
  def to_srt(offset=-(@steps.first.time - 1))

    lines = to_subtitles(offset).strip.lines.map.with_index do |x, i|

      puts ('x: ' + x.inspect).debug if @debug
      raw_times, subtitle = x.split(/ /,2)
      puts ('raw_times: ' + raw_times.inspect).debug if @debug
      start_time, end_time = raw_times.split('-',2)
      times = [("%02d:%02d:%02d,000" % ([0, 0 ] + start_time.split(/\D/)\
                                    .map(&:to_i)).reverse.take(3).reverse), \
               '-->', \
              ("%02d:%02d:%02d,000" % ([0, 0 ] + end_time.split(/\D/).map(&:to_i))\
               .reverse.take(3).reverse)].join(' ')

      [i+1, times, subtitle].join("\n")

    end

    lines.join("\n")    
    
  end
  
  def to_subtitles(offset=-(@steps.first.time - 1))
    
    raw_times = @steps.map {|x| [x.time, x.time + x.audio_duration + 1]} 
    

    times = raw_times.map do |x|

      x.map do |sec|
        a = Subunit.new(units={minutes:60}, seconds: sec+offset).to_h.to_a
        a.map {|x|"%d%s" % [x[1], x[0][0]] }.join('')
      end.join('-')
      
    end
    
    times.zip(@steps.map(&:desc)).map {|x| x.join(' ')}.join("\n")
                          
  end
  
  def transcode_video(avi, mp4)
    
    if block_given? then
      yield(avi, mp4)
    else
      `ffmpeg -i #{avi} #{mp4} -y`
    end
    
  end
  
  def trim_video(video, newvideo)
    
    start = @steps.first.time > 4 ? @steps.first.time - 4 : @steps.first.time
    
    t1, t2 = [start, @steps.last.time - 2 ].map do |step|
      "%02d:%02d:%02d" % (step.to_hms.reverse + [0,0]).take(3).reverse
    end
    
    `ffmpeg -i #{video} -ss #{t1} -t #{t2} -async 1 #{newvideo} -y`
    
  end

end

