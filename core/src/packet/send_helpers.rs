use std::io::Cursor;

use binrw::BinWrite;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpStream,
};

use crate::{
    common::RECEIVE_BUFFER_SIZE, common::timestamp_msecs, config::get_config,
    ipc::kawari::CustomIpcSegment,
};

use super::{
    CompressionType, ConnectionState, ConnectionType, PacketHeader, PacketSegment,
    ReadWriteIpcSegment, SegmentData, SegmentType, compression::compress, parse_packet,
    parse_packet_header,
};

pub async fn send_packet<T: ReadWriteIpcSegment>(
    socket: &mut TcpStream,
    state: &mut ConnectionState,
    connection_type: ConnectionType,
    compression_type: CompressionType,
    segments: &[PacketSegment<T>],
) {
    let (data, uncompressed_size) = compress(state, &compression_type, segments);
    let size = std::mem::size_of::<PacketHeader>() + data.len();

    let header = PacketHeader {
        timestamp: timestamp_msecs(),
        size: size as u32,
        connection_type,
        segment_count: segments.len() as u16,
        compression_type,
        uncompressed_size: uncompressed_size as u32,
        ..Default::default()
    };

    let mut cursor = Cursor::new(Vec::with_capacity(size));
    header.write_le(&mut cursor).unwrap();
    std::io::Write::write_all(&mut cursor, &data).unwrap();

    let buffer = cursor.into_inner();
    assert!(buffer.len() < RECEIVE_BUFFER_SIZE);

    if let Err(e) = socket.write_all(&buffer).await {
        tracing::warn!("Failed to send packet: {e}");
    }
}

pub async fn send_keep_alive<T: ReadWriteIpcSegment>(
    socket: &mut TcpStream,
    state: &mut ConnectionState,
    connection_type: ConnectionType,
    id: u32,
    timestamp: u32,
) {
    let response_packet: PacketSegment<T> = PacketSegment {
        segment_type: SegmentType::KeepAliveResponse,
        data: SegmentData::KeepAliveResponse { id, timestamp },
        ..Default::default()
    };
    send_packet(
        socket,
        state,
        connection_type,
        CompressionType::Uncompressed,
        &[response_packet],
    )
    .await;
}

/// Sends a custom IPC packet to the world server, meant for private server-to-server communication.
/// Returns the first custom IPC segment returned.
pub async fn send_custom_world_packet(segment: CustomIpcSegment) -> Option<CustomIpcSegment> {
    let config = get_config();

    let addr = config.world.get_public_socketaddr();

    let mut stream = TcpStream::connect(addr).await.ok()?;

    let mut packet_state = ConnectionState::None;

    let segment: PacketSegment<CustomIpcSegment> = PacketSegment {
        segment_type: SegmentType::KawariIpc,
        data: SegmentData::KawariIpc(segment),
        ..Default::default()
    };

    send_packet(
        &mut stream,
        &mut packet_state,
        ConnectionType::KawariIpc,
        CompressionType::Uncompressed,
        &[segment],
    )
    .await;

    // Read the response. A single read() isn't guaranteed to return a whole packet (TCP doesn't
    // preserve message boundaries), so read the fixed-size header first to learn the real
    // length, then read exactly that many remaining bytes before parsing. Previously this
    // assumed one read() = one full packet, which could hand parse_packet() a truncated buffer;
    // parse_packet() returns an empty Vec on any parse failure, and indexing segments[0] on that
    // panicked the whole process (see redstrate/Kawari#437).
    let header_size = std::mem::size_of::<PacketHeader>();
    let mut buf = vec![0u8; header_size];
    stream.read_exact(&mut buf).await.ok()?;

    let header = parse_packet_header(&buf);
    let body_size = (header.size as usize).saturating_sub(header_size);
    if body_size > 0 {
        let mut body = vec![0u8; body_size];
        stream.read_exact(&mut body).await.ok()?;
        buf.extend_from_slice(&body);
    }

    let segments = parse_packet::<CustomIpcSegment>(&buf, &mut packet_state);

    match &segments.first()?.data {
        SegmentData::KawariIpc(data) => Some(data.clone()),
        _ => None,
    }
}
