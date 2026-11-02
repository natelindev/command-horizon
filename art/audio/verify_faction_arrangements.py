"""Audit decoded faction arrangements, pinned sources, sample alignment and instrument evidence."""
import argparse
import hashlib
import json
from pathlib import Path

import librosa
import numpy as np
import pyloudnorm
import soundfile as sf
from scipy.signal import welch

ROOT = Path(__file__).resolve().parents[2]
PARTS = {'bastion': {'dark_brass'}, 'helix': {'deep_sub','hypnotic_arp'},
         'frontier': {'slide_guitar','blues_harp'}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stems', type=Path, required=True)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--report', type=Path, default=ROOT/'art/audio/faction-arrangement-verification.json')
    args = parser.parse_args()
    plans=json.loads((ROOT/'art/audio/faction-arrangements.json').read_text())
    result={}
    for faction,plan in plans.items():
        source,rate=sf.read(ROOT/'assets/audio/music'/(plan['track']+'.ogg'),always_2d=True)
        report=json.loads((args.evidence/(faction+'-arrangement.json')).read_text())
        assert set(report['parts'])==PARTS[faction],faction
        assert report['source_sha256']==hashlib.sha256((ROOT/'assets/audio/music'/(plan['track']+'.ogg')).read_bytes()).hexdigest()
        for key,row in report['sources'].items():
            assert hashlib.sha256((ROOT/row['cache']).read_bytes()).hexdigest()==row['sha256'],key
            assert row['license']=='CC0-1.0',key
        stems=[];clips=[]
        for name in ['calm','tension','combat']:
            path=args.stems/(plan['track']+'-'+name+'.ogg')
            data,sr=sf.read(path,always_2d=True)
            assert rate==sr==44100 and data.shape==source.shape,(faction,name,data.shape,source.shape)
            assert np.isfinite(data).all() and np.abs(data).max()<1,(faction,name)
            stems.append(data)
            clips.append(dict(file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),samples=len(data),peak_dbfs=round(float(20*np.log10(np.abs(data).max())),3)))
        combined=sum(stems)
        audition,sr=sf.read(args.evidence/(faction+'-arranged-audition.flac'),always_2d=True)
        assert sr==rate and audition.shape==source.shape
        snr=10*np.log10(np.mean(audition**2)/np.mean((combined-audition)**2))
        assert snr>20,(faction,'encoded stem reconstruction SNR',snr)
        peak=float(20*np.log10(np.abs(combined).max()))
        assert peak<=-1,(faction,'master peak',peak)
        seam=float(np.max(np.abs(combined[0]-combined[-1])))
        assert seam<.01,(faction,'encoded loop seam',seam)
        parts={}
        for name,item in report['parts'].items():
            path=args.evidence/item['file'];data,sr=sf.read(path,always_2d=True)
            assert sr==rate and data.shape==source.shape and np.isfinite(data).all()
            assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
            assert item['events']>=50 and np.mean(data**2)>1e-7,(faction,name)
            parts[name]=dict(sha256=item['sha256'],events=item['events'],integrated_lufs=item['integrated_lufs'])
            if name=='deep_sub':
                frequency,power=welch(data.mean(axis=1),fs=rate,nperseg=16384)
                fraction=float(power[(frequency>=25)&(frequency<=90)].sum()/power.sum())
                assert fraction>.9,('sub-bass spectrum',fraction)
                parts[name]['energy_25_to_90_hz']=round(fraction,5)
        if faction=='frontier':
            slides=[e for e in report['events'] if e['part']=='slide_guitar']
            assert all(e['slide_semitones']<=-2 for e in slides)
            assert all(e['instrument'].startswith('guitar') for e in slides)
            assert all(e['instrument'].startswith('harp') for e in report['events'] if e['part']=='blues_harp')
            isolated,_=sf.read(args.evidence/'frontier-slide_guitar.flac',always_2d=True)
            glides=[]
            for event in [e for e in slides if e['slide_semitones']==-5][:4]:
                measured=[]
                target_hz=librosa.midi_to_hz(event['pitch'])
                for a,b in [(.035,.135),(.26,.36)]:
                    segment=isolated[round((event['seconds']+a)*rate):round((event['seconds']+b)*rate)].mean(axis=1)
                    segment=librosa.resample(segment,orig_sr=rate,target_sr=22050)
                    f0=librosa.yin(segment,fmin=target_hz*.4,fmax=target_hz*1.3,
                                   sr=22050,frame_length=1024,hop_length=128)
                    measured.append(float(np.median(librosa.hz_to_midi(f0))))
                assert measured[1]-measured[0]>1.5,('actual slide trajectory',measured)
                assert abs(measured[1]-event['pitch'])<.35,('slide target tuning',measured,event)
                glides.append(dict(seconds=event['seconds'],early_midi=round(measured[0],4),
                                   settled_midi=round(measured[1],4),target_midi=event['pitch']))
            parts['slide_guitar']['measured_glides']=glides
        result[faction]=dict(samples=len(source),sample_rate=rate,channels=2,bpm=plan['bpm'],stems=clips,
                            mix_peak_dbfs=round(peak,3),integrated_lufs=round(pyloudnorm.Meter(rate).integrated_loudness(combined),3),
                            encoded_loop_boundary_step=seam,reconstruction_snr_db=round(float(snr),3),parts=parts)
        print(faction,result[faction]['mix_peak_dbfs'],'dBFS',round(float(snr),2),'dB reconstruction SNR',flush=True)
    args.report.write_text(json.dumps(dict(factions=result,failures=[],subjective_listening_performed=False),indent=2)+'\n')
    print('report: '+str(args.report))


if __name__=='__main__':
    main()
