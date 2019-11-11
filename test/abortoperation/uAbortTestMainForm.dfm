object AbortTestMainForm: TAbortTestMainForm
  Left = 0
  Top = 0
  Caption = 'Zeos abort test'
  ClientHeight = 334
  ClientWidth = 565
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  DesignSize = (
    565
    334)
  PixelsPerInch = 96
  TextHeight = 13
  object HostNameLabel: TLabel
    Left = 8
    Top = 43
    Width = 55
    Height = 13
    Caption = 'Host name:'
  end
  object ProtocolLabel: TLabel
    Left = 8
    Top = 16
    Width = 43
    Height = 13
    Caption = 'Protocol:'
  end
  object UserNameLabel: TLabel
    Left = 8
    Top = 70
    Width = 55
    Height = 13
    Caption = 'User name:'
  end
  object PasswordLabel: TLabel
    Left = 8
    Top = 97
    Width = 50
    Height = 13
    Caption = 'Password:'
  end
  object DatabaseLabel: TLabel
    Left = 8
    Top = 124
    Width = 50
    Height = 13
    Caption = 'Database:'
  end
  object QueryLabel: TLabel
    Left = 8
    Top = 151
    Width = 34
    Height = 13
    Caption = 'Query:'
  end
  object HostNameEdit: TEdit
    Left = 120
    Top = 35
    Width = 437
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
  end
  object UserNameEdit: TEdit
    Left = 120
    Top = 62
    Width = 437
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 2
  end
  object PasswordEdit: TEdit
    Left = 120
    Top = 89
    Width = 437
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    PasswordChar = '*'
    TabOrder = 3
  end
  object DatabaseEdit: TEdit
    Left = 120
    Top = 116
    Width = 437
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 4
  end
  object ProtocolComboBox: TComboBox
    Left = 120
    Top = 8
    Width = 437
    Height = 21
    Style = csDropDownList
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
  end
  object LogMemo: TMemo
    Left = 8
    Top = 215
    Width = 549
    Height = 110
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 7
  end
  object TestButton: TButton
    Left = 8
    Top = 184
    Width = 549
    Height = 25
    Anchors = [akLeft, akTop, akRight]
    Caption = 'Test!'
    TabOrder = 6
    OnClick = TestButtonClick
  end
  object QueryEdit: TEdit
    Left = 120
    Top = 143
    Width = 437
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 5
  end
  object SQLConnection: TZConnection
    ControlsCodePage = cCP_UTF16
    AutoEncodeStrings = True
    Catalog = ''
    HostName = ''
    Port = 0
    Database = ''
    User = ''
    Password = ''
    Protocol = ''
    Left = 48
    Top = 224
  end
  object SQLQuery: TZQuery
    Connection = SQLConnection
    Params = <>
    Left = 112
    Top = 224
  end
end
