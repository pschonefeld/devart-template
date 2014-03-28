import 'dart:html';
import 'dart:web_audio'; 
import 'dart:typed_data';
import 'dart:async';

bool _clearOnNext = false;
int _time = 0;
var _currentVol;
var _xOffset = 300;
int _y = 0;
List<num> _volumeSeries = [];
Timer _timer;
int _status = 0;

void main() {
    
  //setup
  AudioContext context = new AudioContext();
  OscillatorNode source = context.createOscillator();
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
  processor.onAudioProcess.listen((_){
    if(_status==0){
      
      Uint8List list = new Uint8List(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(list);
      double average = list.fold(0, (prev,elem)=>prev+elem)/list.length;
      if(average>20){
        if(_clearOnNext){
          _volumeSeries.clear();
          _clearOnNext = false;
        }
        String d = querySelector("#svgPath").attributes["d"];
        var x1 = _xOffset - average.truncate();
        var x2 = _xOffset + average.truncate();      
        querySelector("#svgPath").attributes["d"] = "$d L$x1,${_y++} L$x2,${_y++} ";
        _volumeSeries.add(average);
      }
      else{
        querySelector("#svgPath").attributes["d"] = "M${_xOffset},0";
        _y = 0;
        _clearOnNext = true;
      }
    }
  });   
    
  querySelector("#btnPlaySample").onClick.listen((_)=>playSynthesizedSample(gain,source));


  
}

void playSynthesizedSample(GainNode gain,OscillatorNode source){
  int i = 0;
  _status = 1;
  (querySelector("#btnPlaySample") as ButtonElement).disabled = true;  
  _timer = new Timer.periodic(new Duration(milliseconds:50), (_){

    String d = querySelector("#svgPath").attributes["d"];
    var x1 = _xOffset - _volumeSeries[i].truncate();
    var x2 = _xOffset + _volumeSeries[i].truncate();      
    querySelector("#svgPath").attributes["d"] = "$d L$x1,${i*2} L$x2,${i*2}";    
    
    querySelector("#spanGain").text = "${_volumeSeries[i]/100}";
    gain.gain.value = _volumeSeries[i++]/100;
    
    if(i==_volumeSeries.length){
      _timer.cancel();
      gain.gain.value = 0;
      _status = 0;
      (querySelector("#btnPlaySample") as ButtonElement).disabled = false;      
    }
  });
  
}

