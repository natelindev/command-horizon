"""Measure beat positions and local chord anchors for the licensed faction recordings.
Run in the voice/music build environment; updates faction-arrangements.json.
"""
import json,hashlib,sys
from pathlib import Path
import numpy as np
import librosa
import soundfile as sf
from scipy.signal import resample_poly
root=Path(__file__).resolve().parents[2];results={}
for faction,track in [('bastion','hold-the-line'),('helix','perfect-compliance'),('frontier','no-shutdown-code')]:
 path=root/'assets/audio/music'/(track+'.ogg')
 y,sr=librosa.load(path,sr=22050)
 onset=librosa.onset.onset_strength(y=y,sr=sr,hop_length=512)
 tempo,beats=librosa.beat.beat_track(onset_envelope=onset,sr=sr,hop_length=512,trim=False)
 times=librosa.frames_to_time(beats,sr=sr,hop_length=512)
 harm=librosa.effects.harmonic(y)
 chroma=librosa.feature.chroma_stft(y=harm,sr=sr,hop_length=1024,tuning=0)
 chords=[]
 triads=[]
 for pc in range(12):
  for quality,third in [('minor',3),('major',4)]:
   template=np.ones(12)*-.18;template[[pc,(pc+third)%12,(pc+7)%12]]=[1,.8,.7]
   triads.append((pc,quality,third,template))
 # Fit each four-beat phrase to the actual recording, rather than impose a new progression.
 for at in range(0,len(times)-4,4):
  a,b=times[at],times[at+4]
  values=chroma[:,int(a*sr/1024):max(int(a*sr/1024)+1,int(b*sr/1024))].mean(axis=1)
  pc,q,third,_=max(triads,key=lambda row:float(row[3]@values))
  chords.append(dict(seconds=round(float(a),6),end=round(float(b),6),root=pc,quality=q,third=third))
 results[faction]=dict(track=track,source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bpm=round(float(np.asarray(tempo).reshape(-1)[0]),5),beat_times=np.round(times,6).tolist(),chords=chords)
 print(faction,results[faction]['bpm'],'beats',len(times),'chords',len(chords),flush=True)
(root/'art/audio/faction-arrangements.json').write_text(json.dumps(results,indent=2)+'\n')
