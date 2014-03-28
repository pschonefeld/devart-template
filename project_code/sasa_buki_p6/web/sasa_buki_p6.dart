import 'dart:html';
import 'dart:web_audio'; 
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'dart:svg';

bool _clearOnNext = false;
int _time = 0;
var _currentVol;
var _xOffset = 350;
int _y = 0;
List<Sound> _sample = [];
Timer _timer;
int _status = 0;
Map<int,Sample> _samples = {};
bool _collectSample = false;
bool _collectWhiteSpace = true;
int _cols = 10;

class Sound {
  double volume;
  double pitch;
  Sound(this.volume,this.pitch);
}

class Sample {
  List<Sound> sounds = [];
  String pathData;
  int position;
  Sample(src,this.pathData){
    this.sounds.insertAll(0, src);
  }
}

AudioContext context = new AudioContext();

void main() {
    


  OscillatorNode source = context.createOscillator();
  source.type = "triangle"; //"sine","square","sawtooth","triangle","custom" 
  GainNode gain = context.createGainNode();
  source.frequency.value = 400;
  source.connectNode(gain);
  gain.connectNode(context.destination, 0, 0);
  gain.gain.value = 0;
  source.start(0);  

  ScriptProcessorNode  processor = context.createScriptProcessor(2048, 1, 1);
  AnalyserNode analyser = context.createAnalyser();
  analyser.smoothingTimeConstant = 0.3;
  analyser.fftSize = 1024;   
  MediaStreamAudioDestinationNode destination = context.createMediaStreamDestination();
    
 //audio in - connect nodes and input
  window.navigator.getUserMedia(audio:true).then((MediaStream stream) {
    MediaStreamAudioSourceNode mediaStreamSource = context.createMediaStreamSource(stream);
    mediaStreamSource.connectNode(analyser);
    analyser.connectNode(processor);
    processor.connectNode(destination);
  });

  //do stuff here
  processor.onAudioProcess.listen((AudioProcessingEvent e){
    if(_status==0){
      
      Float32List listA = e.inputBuffer.getChannelData(0);
      
      Uint8List listF = new Uint8List(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(listF);

      //Uint8List listA = new Uint8List(analyser.frequencyBinCount);
      //analyser.getByteTimeDomainData(listA);
      double avgVolume = listF.fold(0, (prev,elem)=>prev+elem)/listF.length;
      //double avgFrequency = listA.fold(0, (prev,elem)=>prev+elem)/listA.length;
      if(avgVolume>20){
        if(_clearOnNext){
          _sample.clear();
          _clearOnNext = false;
        }
        String d = querySelector("#svgPath").attributes["d"];
        var x1 = _xOffset - (avgVolume*2).truncate();
        var x2 = _xOffset + (avgVolume*2).truncate();      
        querySelector("#svgPath").attributes["d"] = "$d L$x1,${_y++} L$x2,${_y++} ";
        num pitch = autoCorrelate(listA,context.sampleRate);
        _sample.add(new Sound(avgVolume,pitch));
        //querySelector("#spanGain").text = "pitch: $pitch";
        _collectWhiteSpace = true;
      }
      else{
        if(_collectSample && _collectWhiteSpace){
          Sample newSample = new Sample(_sample,querySelector("#svgPath").attributes["d"]);
          newSample.position = _samples.length;
          _samples[newSample.hashCode] = newSample;
          addVisual(newSample);
          _collectWhiteSpace = false;          
        }
        querySelector("#svgPath").attributes["d"] = "M${_xOffset},0";
        _y = 0;
        _clearOnNext = true;
      }
    }
  });   
    
  querySelector("#btnPlaySample").onClick.listen((_)=>playSynthesizedSample(gain,source,context));
  querySelector("#btnStartSample").onClick.listen((_){
    (querySelector("#btnStartSample") as ButtonElement).disabled = true;
    querySelector("#circleRecord").style.opacity = "1.0";
    _collectSample = true;
  });
  
  querySelector("#btnStopSample").onClick.listen((_){
    (querySelector("#btnStartSample") as ButtonElement).disabled = false;
    querySelector("#circleRecord").style.opacity = "0";    
    _collectSample = false;
  });  
  
}

void playSynthesizedSample(GainNode gain,OscillatorNode source, AudioContext context){
  
  if(_sample==null ||  _sample.length == 0) 
    return;
  
  int i = 0;
  _status = 1;
  (querySelector("#btnPlaySample") as ButtonElement).disabled = true;  
  _timer = new Timer.periodic(new Duration(milliseconds:50), (_){

    String d = querySelector("#svgPath").attributes["d"];
    var x1 = _xOffset - (_sample[i].volume*2).truncate();
    var x2 = _xOffset + (_sample[i].volume*2).truncate();      
    querySelector("#svgPath").attributes["d"] = "$d L$x1,${i*2} L$x2,${i*2}";    
    
    //querySelector("#spanGain").text = "vol: ${_sample[i].volume/100} pitch: ${_sample[i].pitch}";  
    var lower = context.sampleRate~/2093;  // 2093 C7
    var upper = context.sampleRate~/32.7032; // 32.7032 Hz C1
    if(_sample[i].pitch >= lower && _sample[i].pitch <= upper){
      source.frequency.value =  _sample[i].pitch;
    }
    source.connectNode(gain);
    gain.gain.value = _sample[i++].volume/100;
    if(i==_sample.length){
      _timer.cancel();
      gain.gain.value = 0;
      _status = 0;
      (querySelector("#btnPlaySample") as ButtonElement).disabled = false;      
    }
  });
  
}

//ref: Chris Wilson ... http://webaudiodemos.appspot.com/pitchdetect/index.html
num autoCorrelate( buf, sampleRate ) {
  var MIN_SAMPLES = 4;  // corresponds to an 11kHz signal
  var MAX_SAMPLES = 1000; // corresponds to a 44Hz signal
  var SIZE = 1000;
  var best_offset = -1;
  var best_correlation = 0;
  var rms = 0;

  var confidence = 0;
  var currentPitch = 0;

  for (var i=0;i<SIZE;i++) {
    var val = (buf[i] - 128)/128;
    rms += val*val;
  }
  rms = sqrt(rms/SIZE);

  for (var offset = MIN_SAMPLES; offset <= MAX_SAMPLES; offset++) {
    var correlation = 0;
    
    for (var i=0; i<SIZE; i++) {
      if((i+offset)<buf.length)
        correlation += (((buf[i] - 128)/128)-((buf[i+offset] - 128)/128)).abs();
    }
    correlation = 1 - (correlation/SIZE);
    if (correlation > best_correlation) {
      best_correlation = correlation;
      best_offset = offset;
    }
  }
  if ((rms>0.01)&&(best_correlation > 0.01)) {
    confidence = best_correlation * rms * 10000;
    currentPitch = sampleRate/best_offset;
  }
  return currentPitch;
}

void addVisual(Sample sample){
  
  GElement group = querySelector("#gSamples");
  PathElement p = new PathElement();
  p.attributes["d"] = sample.pathData;
  p.attributes["transform"] = "translate(${(sample.position%_cols)*40},${(sample.position~/_cols)*70}) scale(0.2) ";
  p.attributes["stroke"] = "white";
  p.attributes["fill"] = "white";  
  p.dataset["hash"] = "${sample.hashCode}";  
  p.classes.add("sample");
  p.style.cursor = "pointer";
  group.children.add(p);
  p.onClick.listen((e)=>playSample(sample));
  
}

void playSample(Sample sample){
  if(sample.sounds==null ||  sample.sounds.length == 0) 
    return;
  
  OscillatorNode source = context.createOscillator();
  source.type = "triangle"; //"sine","square","sawtooth","triangle","custom" 
  GainNode gain = context.createGainNode();
  source.frequency.value = 400;
  source.connectNode(gain);
  gain.connectNode(context.destination, 0, 0);
  gain.gain.value = 0;
  source.start(0);    
  
  int i = 0;
  Timer timer = new Timer.periodic(new Duration(milliseconds:50), (t){
    String d = querySelector("#svgPath").attributes["d"];
    var x1 = _xOffset - (sample.sounds[i].volume*2).truncate();
    var x2 = _xOffset + (sample.sounds[i].volume*2).truncate();      
    querySelector("#svgPath").attributes["d"] = "$d L$x1,${i*2} L$x2,${i*2}";    
    
    //querySelector("#spanGain").text = "vol: ${_sample[i].volume/100} pitch: ${_sample[i].pitch}";  
    var lower = context.sampleRate~/2093;  // 2093 C7
    var upper = context.sampleRate~/32.7032; // 32.7032 Hz C1
    if(sample.sounds[i].pitch >= lower && sample.sounds[i].pitch <= upper){
      source.frequency.value =  sample.sounds[i].pitch;
    }
    source.connectNode(gain);
    gain.gain.value = sample.sounds[i++].volume/100;
    if(i==sample.sounds.length){
      t.cancel();
      source.stop();  
    }
  });
}


