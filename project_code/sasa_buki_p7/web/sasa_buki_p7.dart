import 'dart:html';
import 'dart:web_audio'; 
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'dart:svg';

bool _clearOnNext = false;
int _time = 0;
var _currentVol;
var _xOffset = 150;
int _y = 0;
List<Sound> _sample = [];
Timer _timer;
int _status = 0;
Map<int,Sample> _samples = {};
bool _collectSample = false;
bool _collectWhiteSpace = false;
int _cols = 10;
int _touchMode = 0; //0 = click; 1 = touch
String _waveType = "sine";
int _volumeCuttoff = 20;

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
  source.type = _waveType; //"sine","square","sawtooth","triangle","custom" 
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

      double avgVolume = listF.fold(0, (prev,elem)=>prev+elem)/listF.length;

      if(avgVolume>_volumeCuttoff){
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
    
  querySelector("#btnPlaySample").onClick.listen((_)=>playLastSample(gain,source,context));
  
  querySelector("#btnStartSample").onClick.listen((_){
    (querySelector("#btnStartSample") as ButtonElement).disabled = true;
    querySelector("#circleRecord").style.opacity = "1.0";
    _sample.clear();
    _collectSample = true;
    _collectWhiteSpace = false;
  });
  
  querySelector("#btnStopSample").onClick.listen((_){
    (querySelector("#btnStartSample") as ButtonElement).disabled = false;
    querySelector("#circleRecord").style.opacity = "0";    
    _collectSample = false;
  });  
  
  querySelector("#btnTouchMode").onClick.listen((_){
    if(_touchMode == 0){
      _touchMode = 1;
      (querySelector("#btnTouchMode") as ButtonElement).text = "touch";
    }
    else {
      _touchMode = 0;
      (querySelector("#btnTouchMode") as ButtonElement).text = "click";
    }
  });    
  
  querySelectorAll(".wave").forEach((i)=>i.onClick.listen((e){
    ButtonElement target = e.target;
    _waveType = target.dataset["wave"];
    querySelectorAll(".wave").forEach((Element elem)=>elem.classes..remove("on")..add("off"));
    querySelectorAll("button[data-wave=$_waveType]").forEach((Element elem)=>elem.classes..remove("off")..add("on"));    
  }));  
  
  querySelector('#rangeVolume').onMouseUp.listen((e) {
      _volumeCuttoff = int.parse(e.target.value);
      querySelector("#volTolerance").text = e.target.value;
  });
  
}

void playLastSample(GainNode gain,OscillatorNode source, AudioContext context){
  
  if(_sample==null ||  _sample.length == 0) 
    return;
  
  int i = 0;
  _status = 1;
  source.type = _waveType;
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

  int col = sample.position%_cols;
  int row = sample.position~/_cols;
  
  GElement group = querySelector("#gSamples");
  
  GElement g = new GElement();
  g.attributes["transform"] = "translate(${col*40},${row*85}) scale(0.2) ";
  
  PathElement p = new PathElement();
  p.attributes
    ..["d"] = sample.pathData
    ..["stroke"] = "white"
    ..["fill"] = "white"  
    ..["hash"] = "${sample.hashCode}"
    ..["pos"] = "$col,$row";  
  p.classes.add("sample");
  g.children.add(p);

  RectElement r = new RectElement();
  r.attributes
    ..["x"] = "${_xOffset-100}"
    ..["y"] = "0"
    ..["width"] = "200"
    ..["height"] = "350"  
    ..["fill"] = "rgba(255,255,255,0)"
    ..["stroke"] = "rgba(100,100,100,1)";
  r.style.cursor = "pointer";  
  g.children.add(r);  
  r.onClick.listen((e){
    if(_touchMode==0) playSample(sample,r);}
  );

  r.onMouseOver.listen((e){
    if(_touchMode==1) playSample(sample,r);}
  );  
  
  r.onTouchStart.listen((e){
    if(_touchMode==1) playSample(sample,r);}
  );  
  
  group.children.add(g);
  
}

void playSample(Sample sample, RectElement rect){
  if(sample.sounds==null ||  sample.sounds.length == 0) 
    return;
  
  rect.attributes["stroke"] = "rgba(255,255,255,1)";
  Timer displayTimer = new Timer.periodic(new Duration(milliseconds:sample.sounds.length*50), (t){
    rect.attributes["stroke"] = "rgba(100,100,100,1)";
    t.cancel();
  });
  
  OscillatorNode source = context.createOscillator();
  source.type = _waveType; //"sine","square","sawtooth","triangle","custom" 
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


