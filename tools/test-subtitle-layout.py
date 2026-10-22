"""Windows self-check: python tools/test-subtitle-layout.py [--real]. Artifacts stay in subtitles/."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'subtitles' / 'layout-selftest'
WORK.mkdir(parents=True, exist_ok=True)
FFMPEG = ROOT.parent / 'ffmpeg.exe'
ASS = r'''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 2
ScaledBorderAndShadow: yes
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: CN,Missing_Font_Subtitle_Test,72,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,15,15,60,1
Style: JP,Arial,65,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,15,15,6,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:02.00,CN,,0,0,0,,这是用来检查放大之后自动换行和双语间距的对白。
Dialogue: 0,0:00:00.00,0:00:03.00,JP,,0,0,0,,字幕の改行と字幕の間隔を確認する台詞です。
Dialogue: 0,0:00:03.00,0:00:04.00,CN,,0,0,0,,单独中文不应该被上一条日文抬高
Dialogue: 0,0:00:04.00,0:00:05.00,CN,,0,0,0,,{\q2\i1}明确换行\N保留第二行，标点不能出现在行首。
Dialogue: 0,0:00:00.00,0:00:03.00,CN,,0,0,0,,{\pos(960,100)}定位翻译保持原样
Dialogue: 0,0:00:05.00,0:00:06.00,CN,,0,0,0,,{\t(0,500,\fs90)}特效保持原样
'''


def run(args):
    return subprocess.run([str(x) for x in args], capture_output=True, timeout=90,
                          creationflags=subprocess.CREATE_NO_WINDOW)


def prepare(source, scale=1.5, stream=-1, media=None):
    request = WORK / f'request-{uuid.uuid4().hex}.json'
    request.write_text(json.dumps(dict(source=str(source), media=str(media) if media else None,
        stream=stream, scale=scale, font='LXGW WenKai', fonts=str(ROOT / 'fonts'),
        ffmpeg=str(FFMPEG), cache=str(WORK / 'cache'))), encoding='utf-8')
    result = run(['powershell.exe', '-NoProfile', '-NonInteractive', '-File',
                  ROOT / 'tools' / 'subtitle-layout.ps1', '-Request', request])
    request.unlink()
    assert result.returncode == 0, result.stderr.decode('utf-8', errors='replace')
    return json.loads(result.stdout)


class Player:
    def __init__(self, watch=None, audio=False, all_scripts=False):
        self.pipe = r'\\.\pipe\subtitle-layout-' + uuid.uuid4().hex
        self.log = WORK / ('mpv-' + uuid.uuid4().hex + '.log')
        self.watch = watch or WORK / ('watch-' + uuid.uuid4().hex)
        args = [ROOT.parent / 'mpv.exe', f'--config-dir={ROOT}', '--idle=yes', '--pause',
            '--no-save-position-on-quit', f'--watch-later-directory={self.watch}',
            '--ao=null' if audio else '--audio=no', '--sub-auto=no', '--keep-open=yes', '--hwdec=no',
            '--force-window=yes', '--geometry=960x540', '--autofit=', '--autofit-larger=',
            f'--input-ipc-server={self.pipe}', f'--log-file={self.log}',
            '--msg-level=sub/ass=debug,subtitle_layout=debug']
        if not all_scripts:
            args += ['--load-scripts=no', f'--script={ROOT / "scripts" / "subtitle-layout.lua"}']
        self.process = subprocess.Popen([str(x) for x in args], stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
        deadline = time.monotonic() + 15
        while True:
            try:
                self.connection = open(self.pipe, 'r+b', buffering=0)
                break
            except OSError:
                if self.process.poll() is not None:
                    raise AssertionError(self.log.read_text(encoding='utf-8', errors='replace')[-4000:])
                if time.monotonic() > deadline:
                    raise AssertionError(self.log.read_text(encoding='utf-8', errors='replace'))
                time.sleep(.05)
        self.buffer = b''
        self.counter = 0

    def cmd(self, *command):
        self.counter += 1
        request_id = self.counter
        self.connection.write((json.dumps(dict(command=command, request_id=request_id)) + '\n').encode())
        while True:
            while b'\n' not in self.buffer:
                chunk = self.connection.read(65536)
                assert chunk, 'mpv IPC closed unexpectedly'
                self.buffer += chunk
            line, self.buffer = self.buffer.split(b'\n', 1)
            response = json.loads(line)
            if response.get('request_id') == request_id:
                if command[0] == 'get_property' and response['error'] in ('property not found', 'property unavailable'):
                    return None
                assert response['error'] == 'success', response
                return response.get('data')

    def get(self, key):
        return self.cmd('get_property', key)

    def wait(self, predicate, timeout=25):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.1)
        raise AssertionError(self.log.read_text(encoding='utf-8', errors='replace')[-8000:])

    def ready(self):
        def completed():
            state = self.get('user-data/subtitle-layout/status')
            if str(state).startswith('error:'):
                return True
            report = self.get('user-data/subtitle-layout/report') or {}
            return state == 'ready' and report.get('track_id') == self.get('sid') and abs(report.get('scale', 0) - self.get('sub-scale')) < .001
        self.wait(completed)
        assert self.get('user-data/subtitle-layout/status') == 'ready', self.get('user-data/subtitle-layout/status')

    def screenshot(self, name, timestamp):
        self.cmd('seek', timestamp, 'absolute+exact')
        self.wait(lambda: abs(self.get('time-pos') - timestamp) < .15)
        time.sleep(.3)
        self.cmd('set_property', 'sub-visibility', True)
        time.sleep(.2)
        self.cmd('screenshot-to-file', str(WORK / f'{name}.png'), 'window')
        self.cmd('set_property', 'sub-visibility', False)
        time.sleep(.2)
        self.cmd('screenshot-to-file', str(WORK / f'{name}-clean.png'), 'window')
        self.cmd('set_property', 'sub-visibility', True)

    def close(self):
        try:
            self.cmd('quit')
        finally:
            self.connection.close()
            self.process.wait(timeout=10)


def selftest():
    fixture = WORK / 'fixture.ass'
    fixture.write_text(ASS, encoding='utf-8')
    original = hashlib.sha256(fixture.read_bytes()).hexdigest()
    report = prepare(fixture)
    assert report['changed'] == 4 and report['skipped'] == 2 and report['pairs'] == 1, report
    output = Path(report['path']).read_text(encoding='utf-8')
    events = [x.split(',', 9) for x in output.splitlines() if x.startswith('Dialogue:')]
    assert '\\N' in events[0][9] and '\\N' in events[1][9]
    assert int(events[0][7]) > int(events[1][7]) + 150, events[:2]
    assert events[2][7] == '60', events[2]
    assert '\\N' in events[3][9] and '\\q2' not in events[3][9]
    assert events[4][9] == r'{\pos(960,100)}定位翻译保持原样'
    assert events[5][9] == r'{\t(0,500,\fs90)}特效保持原样'
    assert 'Missing_Font_Subtitle_Test' in output and ',Arial,' in output
    assert prepare(fixture)['path'] == report['path'], 'cache miss'
    assert prepare(fixture, 2)['path'] != report['path'], 'scale cache collision'
    fixture.write_text(ASS + '\n', encoding='utf-8')
    assert prepare(fixture)['path'] != report['path'], 'source cache not invalidated'
    fixture.write_text(ASS, encoding='utf-8')
    assert hashlib.sha256(fixture.read_bytes()).hexdigest() == original
    top = WORK / 'fixture-top.ass'
    top.write_text(ASS.replace(',2,15,15,60,1', ',8,15,15,60,1').replace(',2,15,15,6,1', ',8,15,15,6,1'), encoding='utf-8')
    top_output = Path(prepare(top)['path']).read_text(encoding='utf-8')
    top_events = [x.split(',', 9) for x in top_output.splitlines() if x.startswith('Dialogue:')]
    assert int(top_events[1][7]) > int(top_events[0][7]) + 150, 'top bilingual order reversed'
    soft = WORK / 'fixture-softbreak.ass'
    soft.write_text(ASS.replace(r'明确换行\N', r'明确换行\n'), encoding='utf-8')
    soft_output = Path(prepare(soft)['path']).read_text(encoding='utf-8')
    assert r'明确换行\N' in soft_output and r'明确换行\n' not in soft_output
    too_large = WORK / 'fixture-too-large.ass'
    too_large.write_text(ASS.replace('这是用来检查放大之后自动换行和双语间距的对白。', '超长对白' * 300), encoding='utf-8')
    try:
        prepare(too_large, 2)
        raise AssertionError('vertical overflow accepted')
    except AssertionError as error:
        assert 'exceeds canvas vertically' in str(error), error
    media = WORK / 'fixture.mkv'
    result = run([FFMPEG, '-nostdin', '-v', 'error', '-y', '-f', 'lavfi', '-i',
        'color=c=black:s=1920x1080:r=24:d=7', '-i', fixture, '-map', '0:v', '-map', '1:s',
        '-c:v', 'libx264', '-preset', 'ultrafast', '-c:s', 'ass', '-metadata:s:s:0', 'language=chi',
        '-disposition:s:0', 'default',
        '-attach', ROOT / 'fonts' / 'LXGWWenKai-Regular.ttf',
        '-metadata:s:t', 'mimetype=application/x-truetype-font', media])
    assert result.returncode == 0, result.stderr
    embedded = prepare(media, stream=1, media=media)
    assert embedded['pairs'] == 1 and list(Path(embedded['fonts']).glob('attachment-*'))
    player = Player()
    try:
        player.cmd('loadfile', str(media))
        player.ready()
        assert player.get('sub-ass-override') in (True, 'yes'), player.get('sub-ass-override')
        assert player.get('sub-scale') == 1.5
        player.screenshot('fixture-1.5', 1)
        player.cmd('set_property', 'sub-scale', 2)
        player.ready()
        # Wait for the debounce and the subsequent actual replacement.
        time.sleep(.4)
        player.ready()
        player.screenshot('fixture-2.0', 1)
        tracks = player.get('track-list')
        original_id = next(t['id'] for t in tracks if t['type'] == 'sub' and not t.get('external'))
        player.cmd('set_property', 'sid', original_id)
        player.cmd('set_property', 'sub-scale', 1.3)
        player.cmd('set_property', 'sid', 'no')
        time.sleep(2)
        assert player.get('sid') is False, 'stale result selected a subtitle'
        player.cmd('set_property', 'sid', original_id)
        player.ready()
        player.cmd('set_property', 'sub-scale', 1.4)
        player.wait(lambda: player.get('user-data/subtitle-layout/status') == 'processing')
        player.cmd('set_property', 'sid', 'no')
        time.sleep(1)
        assert player.get('sid') is False, 'running subprocess reselected stale subtitle'
        player.cmd('set_property', 'sid', original_id)
        player.ready()
        player.cmd('set_property', 'sub-scale', 1.3)
        time.sleep(.4)
        player.ready()
        text = player.log.read_text(encoding='utf-8', errors='replace')
        assert 'Using default font family' in text and 'LXGWWenKai' in text, 'missing font fallback not observed'
        assert 'Arial' in text, 'installed font not observed'
        assert 'Lua error' not in text and 'stack traceback' not in text, text[-6000:]
        player.cmd('set_property', 'sub-delay', .35)
        player.cmd('write-watch-later-config')
        player.cmd('set_property', 'sid', 'no')
    finally:
        player.close()
    saved = player.watch / hashlib.md5(str(media).encode()).hexdigest().upper()
    resume = saved.read_text(encoding='utf-8')
    assert 'sid=1\n' in resume and 'sub-ass-override=yes' not in resume, resume
    resumed = Player(watch=player.watch, all_scripts=True)
    try:
        resumed.cmd('loadfile', str(media))
        resumed.ready()
        assert abs(resumed.get('sub-scale') - 1.3) < .001
        assert abs(resumed.get('sub-delay') - .35) < .001
        assert resumed.get('user-data/subtitle-layout/report')['pairs'] == 1
        srt = WORK / 'fixture.srt'
        srt.write_text('1\n00:00:00,000 --> 00:00:03,000\n普通 SRT 字幕保持原生样式和换行\n', encoding='utf-8')
        resumed.cmd('sub-add', str(srt), 'select')
        resumed.wait(lambda: resumed.get('user-data/subtitle-layout/status') == 'native')
        assert resumed.get('sub-ass-override') == 'scale'
        assert abs(resumed.get('sub-delay') - .35) < .001
        resumed.screenshot('srt-native', 1)
        log = resumed.log.read_text(encoding='utf-8', errors='replace')
        assert '[uosc]' in log and 'Lua error' not in log and 'stack traceback' not in log
    finally:
        resumed.close()
    print('PASS: wrapping, bilingual separation, special tags, source/cache preservation, embedded fonts, font logs, IPC scale, stale cancellation, resume and SRT')


def realtest():
    anime = Path(r'Z:\media\tv\迷宫饭 (2024) [tmdbid=207784]\Season 01\迷宫饭.S01E01.mkv')
    subtitle = anime.with_name('迷宫饭.S01E01.scjp.default.ass')
    legal = Path(r'Z:\media\tv\胜者即是正义 (2012) [tmdbid=46234]\Season 01\胜者即是正义.S01E01.1080p.BluRay.H265.FLAC.mkv')
    player = Player(audio=True)
    try:
        player.cmd('loadfile', str(anime))
        player.wait(lambda: player.get('path') == str(anime) and (player.get('duration') or 0) > 0)
        player.cmd('sub-add', str(subtitle), 'select')
        player.ready()
        audio_track = player.get('aid')
        assert audio_track not in (False, None)
        assert player.get('user-data/subtitle-layout/report')['pairs'] > 0
        for scale in (1, 1.5, 2):
            player.cmd('set_property', 'sub-scale', scale)
            time.sleep(.4)
            player.ready()
            player.screenshot(f'anime-{scale}-dialogue', 24)
            player.screenshot(f'anime-{scale}-sign', 440)
            player.screenshot(f'anime-{scale}-ending', 1450)
            player.cmd('set_property', 'fullscreen', True)
            time.sleep(.4)
            player.screenshot(f'anime-{scale}-fullscreen', 24)
            player.cmd('set_property', 'fullscreen', False)
            time.sleep(.3)
            assert player.get('aid') == audio_track, 'ASS processing changed audio track'
        player.cmd('loadfile', str(legal))
        player.wait(lambda: player.get('path') == str(legal) and (player.get('duration') or 0) > 0)
        player.wait(lambda: str(player.get('user-data/subtitle-layout/status')).startswith('image:'))
        assert player.get('sub-scale') == 1
        audio_track = player.get('aid')
        chinese = [t['id'] for t in player.get('track-list') if t['type'] == 'sub' and t.get('lang') in ('chi', 'zho', 'zh')]
        assert len(chinese) == 2
        for i, track_id in enumerate(chinese):
            player.cmd('set_property', 'sid', track_id)
            player.cmd('set_property', 'sub-scale', 1.2)
            player.screenshot(f'legal-{i}-1.2', 180)
            assert player.get('sub-scale') == 1.2
            assert player.get('sub-ass-override') == 'scale'
            assert player.get('aid') == audio_track, 'PGS scaling changed audio track'
        player.cmd('set_property', 'sid', 'no')
        player.cmd('sub-add', str(subtitle), 'select')
        player.ready()
        assert player.get('sub-scale') == 1.5, 'image scale leaked into text'
        player.cmd('set_property', 'sid', chinese[0])
        time.sleep(.2)
        assert player.get('sub-scale') == 1.2, 'text scale leaked into image'
        player.cmd('write-watch-later-config')
        assert 'Lua error' not in player.log.read_text(encoding='utf-8', errors='replace')
    finally:
        player.close()
    resumed = Player(watch=player.watch)
    try:
        resumed.cmd('loadfile', str(legal))
        resumed.wait(lambda: str(resumed.get('user-data/subtitle-layout/status')).startswith('image:'))
        assert abs(resumed.get('sub-scale') - 1.2) < .001, 'PGS resume scale lost'
    finally:
        resumed.close()
    print('PASS: real ASS/PGS track selection and independent scale; screenshots in', WORK)


if __name__ == '__main__':
    selftest()
    if '--real' in sys.argv:
        realtest()
