"""Encode each rigid tread shoe's capsule coordinate in exported UV channels."""
import math


def encode(obj, distance, half, radius, height):
    # Two constant UV channels per shoe survive rigid mesh joining and glTF export.
    uv = obj.data.uv_layers.get('UVMap') or obj.data.uv_layers.new(name='UVMap')
    extra = obj.data.uv_layers.new(name='TrackProfile')
    for loop in obj.data.loops:
        uv.data[loop.index].uv = (distance, half)
        extra.data[loop.index].uv = (radius, height)


def capsule(s, half, radius, height):
    straight = half * 2
    arc = math.pi * radius
    s %= 2 * straight + 2 * arc
    if s < straight:
        return -half + s, height + radius, 0.0
    s -= straight
    if s < arc:
        a = math.pi / 2 - s / radius
        return half + radius * math.cos(a), height + radius * math.sin(a), a - math.pi / 2
    s -= arc
    if s < straight:
        return half - s, height - radius, -math.pi
    a = -math.pi / 2 - (s - straight) / radius
    return -half + radius * math.cos(a), height + radius * math.sin(a), a - math.pi / 2
