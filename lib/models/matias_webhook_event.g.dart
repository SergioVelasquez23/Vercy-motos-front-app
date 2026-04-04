// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matias_webhook_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatiasWebhookEvent _$MatiasWebhookEventFromJson(Map<String, dynamic> json) =>
    MatiasWebhookEvent(
      id: json['id'] as String?,
      event: json['event'] as String,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      data: json['data'] == null
          ? null
          : WebhookData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MatiasWebhookEventToJson(MatiasWebhookEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'event': instance.event,
      'timestamp': instance.timestamp?.toIso8601String(),
      'data': instance.data,
    };

WebhookData _$WebhookDataFromJson(Map<String, dynamic> json) => WebhookData(
  documentId: json['document_id'] as String?,
  documentNumber: json['document_number'] as String?,
  documentType: json['document_type'] as String?,
  status: json['status'] as String?,
  customerId: json['customer_id'] as String?,
  customerEmail: json['customer_email'] as String?,
  totalAmount: (json['total_amount'] as num?)?.toDouble(),
  emailId: json['email_id'] as String?,
  recipient: json['recipient'] as String?,
  subject: json['subject'] as String?,
  paymentId: json['payment_id'] as String?,
  paymentMethod: json['payment_method'] as String?,
  amount: (json['amount'] as num?)?.toDouble(),
  quotaUsed: json['quota_used'] as int?,
  quotaLimit: json['quota_limit'] as int?,
  tokenExpiryDate: json['token_expiry_date'] as String?,
  message: json['message'] as String?,
);

Map<String, dynamic> _$WebhookDataToJson(WebhookData instance) =>
    <String, dynamic>{
      'document_id': instance.documentId,
      'document_number': instance.documentNumber,
      'document_type': instance.documentType,
      'status': instance.status,
      'customer_id': instance.customerId,
      'customer_email': instance.customerEmail,
      'total_amount': instance.totalAmount,
      'email_id': instance.emailId,
      'recipient': instance.recipient,
      'subject': instance.subject,
      'payment_id': instance.paymentId,
      'payment_method': instance.paymentMethod,
      'amount': instance.amount,
      'quota_used': instance.quotaUsed,
      'quota_limit': instance.quotaLimit,
      'token_expiry_date': instance.tokenExpiryDate,
      'message': instance.message,
    };
