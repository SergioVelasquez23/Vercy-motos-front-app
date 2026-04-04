import 'package:json_annotation/json_annotation.dart';

part 'matias_webhook_event.g.dart';

@JsonSerializable()
class MatiasWebhookEvent {
  final String? id;
  final String event;
  final DateTime? timestamp;
  final WebhookData? data;

  MatiasWebhookEvent({this.id, required this.event, this.timestamp, this.data});

  factory MatiasWebhookEvent.fromJson(Map<String, dynamic> json) =>
      _$MatiasWebhookEventFromJson(json);

  Map<String, dynamic> toJson() => _$MatiasWebhookEventToJson(this);
}

@JsonSerializable()
class WebhookData {
  @JsonKey(name: 'document_id')
  final String? documentId;

  @JsonKey(name: 'document_number')
  final String? documentNumber;

  @JsonKey(name: 'document_type')
  final String? documentType;

  final String? status;

  @JsonKey(name: 'customer_id')
  final String? customerId;

  @JsonKey(name: 'customer_email')
  final String? customerEmail;

  @JsonKey(name: 'total_amount')
  final double? totalAmount;

  // Email events
  @JsonKey(name: 'email_id')
  final String? emailId;

  final String? recipient;
  final String? subject;

  // Payment events
  @JsonKey(name: 'payment_id')
  final String? paymentId;

  @JsonKey(name: 'payment_method')
  final String? paymentMethod;

  final double? amount;

  // Quota events
  @JsonKey(name: 'quota_used')
  final int? quotaUsed;

  @JsonKey(name: 'quota_limit')
  final int? quotaLimit;

  @JsonKey(name: 'token_expiry_date')
  final String? tokenExpiryDate;

  final String? message;

  WebhookData({
    this.documentId,
    this.documentNumber,
    this.documentType,
    this.status,
    this.customerId,
    this.customerEmail,
    this.totalAmount,
    this.emailId,
    this.recipient,
    this.subject,
    this.paymentId,
    this.paymentMethod,
    this.amount,
    this.quotaUsed,
    this.quotaLimit,
    this.tokenExpiryDate,
    this.message,
  });

  factory WebhookData.fromJson(Map<String, dynamic> json) =>
      _$WebhookDataFromJson(json);

  Map<String, dynamic> toJson() => _$WebhookDataToJson(this);
}
