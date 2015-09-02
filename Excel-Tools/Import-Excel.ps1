<#
  .SYNOPSIS
    Import data from an  Excel spreadsheet based on a given worksheet and cell or range of cells

  .DESCRIPTION
    Imports an Excel spreadsheet and returns an array of requested cell or range

  .PARAMETER Path
    Mandatory. Path of where the excel sheet is to be loaded

  .PARAMETER Workbook
    Mandatory. Name of Workbook the data is located in
      
  .PARAMETER Cell
    Optional. Reference of the cell to load data from in Excel format e.g. G12 (Default is A1)
          
  .PARAMETER Range
    Optional. Reference of the range to load data from in Excel format e.g. G12:H19

  .PARAMETER debug
    Optional. Enables Verbose output

  .INPUTS
    Parameters above

  .OUTPUTS
    $ExcelData returned containing cell data as a string in $ExcelData[0] and range data as an array in $ExcelData[1]

  .EXAMPLE
            write-host "Loading workbook"
        Start-LoadExcel -Path "Test.xlsx" # -debug

            write-host "Getting list of worksheets"
        $ExcelWorksheets = Get-worksheets #-debug
            write-host "My file's worksheets are in the string ExcelWorksheets: " $ExcelWorksheets

            write-host "Finding Excel cell and range references"
        $ExcelData = Get-ExcelData -Worksheet "MySheet"  -Cell "I7" -Range "I8:I15" #-debug
            write-host "My Cell's data is in the string ExcelData[0]: " $ExcelData[0]
            write-host "My Range's data is in the array ExcelData[1]: " $ExcelData[1]
            write-host "Closing workbook"
        Start-CloseExcel #-debug

  .NOTE
    Only works if Excel is installed

#>




#Clear Up testing#
##################
#Remove for Prod#
#
try {
    Remove-Variable * -ErrorAction SilentlyContinue
} 
catch {
    $_.ExceptionMessage
}
###################


Function Start-LoadExcel ([string]$Path, [switch]$debug) {
    if($debug){
        Write-Host "`tLoading $Path..."
    }
    try {
        $Global:Path = Resolve-Path $Path
        $Global:ExcelCOM = New-Object -com "Excel.Application"
        $Global:ExcelCOM.Visible = $false
        $Global:WorkBook = $Global:ExcelCOM.workbooks.open($Global:Path)
    } catch {
        if($debug){
            write-host "`t[ERROR] $_.exceptionmes"
        } 
    }
 }
    

Function Get-worksheets ([switch]$debug) {
    #Check is a sheet as been specified and use the 1st in the workbook if not
        
    try{
        if($debug){
            write-host "`tParsing available workbooks"
        }
            
        $AWSheets += @()
        foreach ($AWSheet in $Global:Workbook.Worksheets){
            $AWSheets += @($AWSheet.Name)
        }
            

        if($debug){
            write-host "`tFound $AWSheets"
        }
        return $AWSheets

    } catch {
        if($debug){
            write-host "`t[ERROR] $_.exceptionmessage"
        }
   
    } #End catch
  
	
} #End Function


Function Get-ExcelData ([string]$Path, [string]$WorkSheet, [string]$Cell, [string]$Range, [switch]$debug) {
 
        #Check is a sheet as been specified and use the 1st in the workbook if not
        if (-not $Worksheet) {
            if($debug){
                Write-Host "`tNo worksheet specified, defaulting to first in the workbook."
            }
            $ActiveWorksheet = $Worksheet.ActiveSheet
        } else {
            #handling for a badly specified worksheet
            try {
                $ActiveWorksheet = $WorkBook.Sheets.Item($WorkSheet)
            }
            Catch {
                if($debug){
                    write-host "`t[Error] $WorkSheet was unable to be loaded, $_.exceptionmessage"
                }
            }
        }

        #No Cell specified
        If (-not $Cell){
            if($debug){
                Write-Host "`tNo cell specified, defaulting to cell A1 (Cell might not be required output but we need one or the output is not right"
                $CellColumn = "A"
                $CellRow = "1"
            }
        }
            
        
          
        if($debug){
            write-host "`tOpening worksheet..."
        }

	    $AWName = $ActiveWorksheet.Name
	    $AWColumns = $ActiveWorksheet.UsedRange.Columns.Count
	    $AWLines = $ActiveWorksheet.UsedRange.Rows.Count
        

        if($debug){
  	        write-host "`tWorksheet $AWName contains $AWColumns columns and $AWLines lines of data"
        }
    
        if ($cell){
            try {
                if($debug){
  	                write-host "`t Locating $Cell"
                }
                $CellData = $ActiveWorksheet.Cells.Range($Cell).text
                
                
                if($debug){
  	                write-host "`t`t Found $CellData"
                }
            }
            Catch {
                if($debug){
                    write-host "`t `t[Error] $WorkSheet was unable to be loaded, $_.exceptionmessage"
                }
            }
    
        }

        if ($Range){
            try {
                if($debug){
                    write-host "`t Locating $Range"
                }
               
                [string[]]$Header

                $ColumnStart = ($($Range -split ":")[0] -replace "[0-9]", "").ToUpperInvariant()
                $ColumnEnd = ($($Range -split ":")[1] -replace "[0-9]", "").ToUpperInvariant()
                [int]$RowStart = $($Range -split ":")[0] -replace "[a-zA-Z]", ""
                [int]$RowEnd = $($Range -split ":")[1] -replace "[a-zA-Z]", ""

                $ColumnStart = Get-ExcelColumnInt $ColumnStart
                $ColumnEnd = Get-ExcelColumnInt $ColumnEnd
                $Columns = $ColumnEnd - $ColumnStart + 1



                if($Header -and $Header.count -gt 0){
                    if($Header.count -ne $Columns){
                        if($debug){
  	                        write-host "`t Found '$columns' columns, provided $($header.count) headers.  You must provide a header for every column."
                        }
                    }
                } else {
                    $Header = @( 
                        foreach ($Column in $ColumnStart..$ColumnEnd){
                            $ActiveWorksheet.Cells.Item(1,$Column).Value2
                        }
                    )
                }


                [string[]]$SelectedHeaders = @( $Header | select -Unique )

                if($RowStart -eq 1 -and $RowEnd -ne 1){
                    $RowStart += 1
                }


                foreach($Row in ($RowStart)..$RowEnd){
                    $RowData = @{}
                    $HeaderCol = 0

                    foreach($Column in $ColumnStart..$ColumnEnd){
                        $Name  = $Header[$HeaderCol]
                        $Value = $ActiveWorkSheet.Cells.Item($Row,$Column).Value2
                        $HeaderCol++



                        if($debug){
  	                        write-host "`t Row: $Row, Column: $Column, HeaderCol: $HeaderCol, Name: $Name, Value = $Value"
                        }
                                   
                        #Handle dates, they're too common to overlook... Could use help, not sure if this is the best regex to use?
                        $Format = $ActiveWorkSheet.Cells.Item($Row,$Column).style.numberformat.format
                        if($Format -match '\w{1,4}/\w{1,2}/\w{1,4}( \w{1,2}:\w{1,2})?'){
                            Try{
                                $Value = [datetime]::FromOADate($Value)
                            } Catch {

                            if($debug){
  	                            write-host "`t Error converting '$Value' to datetime"
                            }
                        }
                        if($RowData.ContainsKey($Name) ){
                            if($debug){
  	                            write-host "`t Duplicate header for '$Name' found, with value '$Value', in row $Row"
                            }
                        } else {
                            $RowData.Add($Name, $Value)
                        }
                    }
                    New-Object -TypeName PSObject -Property $RowData | Select -Property $SelectedHeaders
                }



                if($debug){
  	                write-host "`t `tFound $RangeData"
                }

                }#end foreach
            } Catch {
                if($debug){
                    write-host "`t`t[Error] $_.exceptionmessage"
                }
            }
    
        }
	
    return $CellData, $RangeData #| Out-Null  #Return values and supress the output
    
}


Function Start-CloseExcel([switch]$debug) {
    if($debug){
        Write-Host "`tClosing $Global:Path..."
    }
    try {
        $Global:ExcelCOM.Quit()
    } catch {
        if($debug){
            write-host "`t[ERROR] $_.exceptionmes"
        } 
    }
 }


Function Get-ExcelColumnInt {
# Thanks to http://stackoverflow.com/questions/667802/what-is-the-algorithm-to-convert-an-excel-column-letter-into-its-number
	[cmdletbinding()]
		param($ColumnName)
	[int]$Sum = 0
	for ($i = 0; $i -lt $ColumnName.Length; $i++)
	{ 
		$sum *= 26
		$sum += ($ColumnName[$i] - 65 + 1)
	}
	$sum
}



write-host "Loading workbook"
Start-LoadExcel -Path "Test.xlsx" # -debug

#write-host "Getting list of worksheets"
#$ExcelWorksheets = Get-worksheets #-debug
#write-host "My file's worksheets are in the string ExcelWorksheets: " $ExcelWorksheets

write-host "Finding Excel cell and range references"
$ExcelData = Get-ExcelData -Worksheet "Sheet1" -Range "A1:B7" #-debug
write-host "My Cell's data is in the string ExcelData[0]: " $ExcelData[0]
write-host "My Range's data is in the array ExcelData[1]: " $ExcelData[1]

write-host "Closing workbook"
Start-CloseExcel #-debug


