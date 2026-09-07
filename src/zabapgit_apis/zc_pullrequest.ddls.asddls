@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pull Request API View'
@Metadata.allowExtensions: true
define root view entity ZC_PullRequest
  provider contract transactional_query
  as projection on ZI_PullRequest
{
  key ParentRequest,
  key TaskRequest,
      PrId,
      RequestStatus,
      PrStatus,
      Owner,
      ExceptionReason,
      CreatedBy,
      CreatedOn,
      CreatedAt,
      ChangedBy,
      ChangedOn,
      ChangedAt
}
